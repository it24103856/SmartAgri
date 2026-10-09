import os
import unittest
from unittest.mock import AsyncMock, patch
from uuid import uuid4

from pydantic import ValidationError

import farmer_ai as ai


def request(**changes):
    values = dict(workflow_id=uuid4(), farm_id=1, objective="Compare soil fit",
                  planting_month=4, soil_type="sandy loam", irrigation_type="drip",
                  well_drained=True, temperature_c=23, soil_ph=5.7,
                  elevation_m=100, upcountry_wet_zone=False)
    values.update(changes)
    return ai.FarmAnalysisRequest(**values)


def only(*ids):
    return [crop for crop in ai.CROPS if crop not in ids]


class CatalogTests(unittest.TestCase):
    def test_new_ids_and_all_candidates(self):
        self.assertEqual(len(ai.CROPS), 10)
        for crop in ai.CROPS:
            self.assertEqual(request(excluded_crop_ids=[crop]).excluded_crop_ids, [crop])
        self.assertEqual(len(ai.EvidenceSelection(crop_ids=list(ai.CROPS)).crop_ids), 10)
        self.assertEqual(len(ai.Ranking(crop_ids=list(ai.CROPS)).crop_ids), 10)

    def test_unknown_and_duplicate_ids_rejected(self):
        for ids in (["rice"], ["tomato", "tomato"]):
            for model, field in ((ai.FarmAnalysisRequest, "excluded_crop_ids"),
                                 (ai.EvidenceSelection, "crop_ids"), (ai.Ranking, "crop_ids")):
                with self.subTest(model=model, ids=ids), self.assertRaises(ValidationError):
                    if model is ai.FarmAnalysisRequest:
                        request(**{field: ids})
                    else:
                        model(**{field: ids})
            with self.assertRaises(ValueError):
                ai.lookup_crop_requirements(ids)

    def test_missing_evidence_is_not_a_conflict_or_a_fit(self):
        crop = ai.lookup_crop_requirements(["carrot"])
        row = ai.evaluate_conditions(request(), crop)["carrot"]
        self.assertFalse(row["eligible"])
        self.assertEqual(row["suitability"], "INSUFFICIENT_EVIDENCE")
        self.assertEqual(row["conflicts"], [])
        crop["carrot"]["well_drained"] = None
        row = ai.evaluate_conditions(request(well_drained=False), crop)["carrot"]
        self.assertEqual(row["conflicts"], [])

    def test_known_rules_change_fit(self):
        records = ai.lookup_crop_requirements(["chilli", "brinjal", "okra", "luffa", "cabbage"])
        good = ai.evaluate_conditions(request(), records)
        hot = ai.evaluate_conditions(request(temperature_c=35), records)
        high = ai.evaluate_conditions(request(elevation_m=600), records)
        wet = ai.evaluate_conditions(request(upcountry_wet_zone=True), records)
        ph = ai.evaluate_conditions(request(soil_ph=6.2), records)
        self.assertTrue(good["chilli"]["eligible"])
        self.assertEqual(hot["chilli"]["suitability"], "UNSUITABLE")
        self.assertTrue(good["luffa"]["eligible"])
        self.assertFalse(high["luffa"]["eligible"])
        self.assertTrue(good["okra"]["eligible"])
        self.assertFalse(wet["okra"]["eligible"])
        self.assertTrue(good["brinjal"]["eligible"])
        self.assertFalse(ph["brinjal"]["eligible"])
        self.assertTrue(ph["cabbage"]["eligible"])

    def test_months_are_guidance_and_rainfall_not_converted(self):
        rows = ai.evaluate_conditions(request(planting_month=1, rainfall_mm_month=2500),
                                      ai.lookup_crop_requirements(["chilli"]))
        self.assertTrue(rows["chilli"]["eligible"])
        self.assertTrue(any("seasonal confirmation" in item for item in rows["chilli"]["checks_needed"]))

    def test_lookup_returns_independent_records(self):
        rows = ai.lookup_crop_requirements(["chilli"])
        rows["chilli"]["temperature_c"][0] = -10
        self.assertEqual(ai.CROPS["chilli"]["temperature_c"], [21, 27])


class WorkflowTests(unittest.IsolatedAsyncioTestCase):
    async def run_case(self, req, alter=None):
        state = {"steps": [], "recommendations": [], "missing_fields": []}
        roles = []

        async def call(client, model, role, instruction, payload, schema, trace):
            roles.append(role)
            trace.append({"agent": role, "status": "COMPLETED"})
            if schema is ai.Plan:
                return ai.Plan(steps=["EvidenceAgent", "CropAnalyst", "SafetyReviewer"], priority="soil_fit")
            if schema is ai.EvidenceSelection:
                ids = payload["allowed_crop_ids"]
                return schema(crop_ids=alter(ids) if alter else ids)
            if schema is ai.Ranking:
                return schema(crop_ids=payload["eligible_crop_ids"])
            return ai.Review(accepted=True)

        await ai.run_workflow(req, None, "test", state, call=call)
        return state, roles

    async def test_exclusions_and_three_result_cap_preserve_stages(self):
        state, roles = await self.run_case(request(excluded_crop_ids=["chilli", "okra", "brinjal"]))
        self.assertEqual(state["status"], "COMPLETED")
        self.assertEqual(len(state["recommendations"]), 3)
        self.assertGreater(len(state["validation"]["eligible_crop_ids"]), 3)
        self.assertTrue(all(row["crop_id"] not in ["chilli", "okra", "brinjal"]
                            for row in state["recommendations"]))
        self.assertEqual(roles, ["Planner", "EvidenceAgent", "CropAnalyst", "SafetyReviewer"])
        self.assertTrue(all(row["reasons"] for row in state["recommendations"]))

    async def test_fewer_than_three(self):
        state, _ = await self.run_case(request(excluded_crop_ids=only("tomato")))
        self.assertEqual([row["crop_id"] for row in state["recommendations"]], ["tomato"])

    async def test_all_excluded_without_provider(self):
        req = request(excluded_crop_ids=list(ai.CROPS), well_drained=None)
        state, roles = await self.run_case(req)
        self.assertEqual(state["error_code"], "ALL_CROPS_EXCLUDED")
        self.assertEqual(roles, [])
        with patch.dict(os.environ, {}, clear=True):
            state = await ai.analyze_farm(req)
        self.assertEqual(state["status"], "NO_MATCH")
        self.assertEqual(state["recommendations"], [])

    async def test_no_suitable_candidates(self):
        state, roles = await self.run_case(request(well_drained=False))
        self.assertEqual(state["status"], "NO_MATCH")
        self.assertEqual(state["error_code"], "NO_SUITABLE_CROPS")
        self.assertEqual(state["recommendations"], [])
        self.assertEqual(set(row["suitability"] for row in state["tool_results"].values()), {"UNSUITABLE"})

    async def test_missing_farm_data(self):
        state, _ = await self.run_case(request(well_drained=None, temperature_c=None,
                                              soil_ph=None, elevation_m=None, upcountry_wet_zone=None))
        self.assertEqual(state["status"], "NEEDS_INPUT")
        self.assertIn("well_drained", state["missing_fields"])
        self.assertIn("soil_ph", state["missing_fields"])
        self.assertEqual(state["recommendations"], [])

    async def test_missing_crop_evidence(self):
        state, _ = await self.run_case(request(excluded_crop_ids=only("carrot")))
        self.assertEqual(state["status"], "NO_MATCH")
        self.assertEqual(state["tool_results"]["carrot"]["suitability"], "INSUFFICIENT_EVIDENCE")
        state, _ = await self.run_case(request(excluded_crop_ids=only("carrot"), well_drained=None))
        self.assertEqual(state["status"], "NO_MATCH")
        self.assertEqual(state["missing_fields"], [])

    async def test_partial_data_only_recommends_supported_crops(self):
        state, _ = await self.run_case(request(temperature_c=None, soil_ph=None, elevation_m=None))
        self.assertEqual([row["crop_id"] for row in state["recommendations"]], ["okra"])

    async def test_evidence_must_cover_allowed_ids(self):
        with self.assertRaisesRegex(ValueError, "INVALID_TOOL_ARGUMENTS"):
            await self.run_case(request(), alter=lambda ids: ids[:-1])

    async def test_provider_failure_never_returns_fixed_recommendations(self):
        with patch.dict(os.environ, {"GEMINI_API_KEY": "test-only", "FARM_AI_MODEL": "test"}), \
                patch.object(ai, "run_workflow", AsyncMock(side_effect=RuntimeError("provider failure"))):
            state = await ai.analyze_farm(request())
        self.assertEqual(state["status"], "FAILED")
        self.assertEqual(state["recommendations"], [])
        self.assertFalse(state["validation"]["passed"])


if __name__ == "__main__":
    unittest.main()
