# Farm AI catalog v2

Dataset: `doa-2026-10-05-v2`, verified 5 October 2026. The single source of
catalog IDs and rules is `crop_catalog.json`. Python reads it relative to its
source; ASP.NET links it into build/publish output and exposes its names/IDs
through the existing farmer-authenticated `GET /api/AI/crop-catalog` route.
Flutter fetches that route for exclusions. Include the JSON when packaging the
Python service and rebuild/restart both services together after catalog edits.

## Verified Department of Agriculture sources

| Crop | Source | Encoded screening evidence |
| --- | --- | --- |
| Chilli | https://doa.gov.lk/field-crops-chilli-si/ | Temperature, maximum elevation, drainage, preferred soil, approximate seasonal months |
| Okra | https://doa.gov.lk/hordi-crop-okra/ | Upcountry wet zone exclusion, drainage, approximate seasonal months |
| Brinjal | https://doa.gov.lk/hordi-crop-brinjal/ | pH, maximum elevation, drainage |
| Tomato | https://doa.gov.lk/hordi-crop-tomato/ | Optimum temperature and pH, upcountry wet zone exclusion, drainage |
| Cabbage | https://doa.gov.lk/hordi-crop-cabbage/ | Best pH, drainage, preferred soil |
| Carrot | https://doa.gov.lk/hordi-crop-carrot/ | Drainage only; insufficient environmental evidence for recommendation |
| Pumpkin | https://doa.gov.lk/hordi-crop-pumpkin/ | pH, drainage |
| Bitter gourd | https://doa.gov.lk/hordi-crop-bitter-gourd/ | pH, drainage, approximate seasonal months |
| Luffa | https://doa.gov.lk/hordi-crop-luffa/ | pH, maximum elevation, drainage, preferred soil |
| Snake gourd | https://doa.gov.lk/hordi-crop-snake-gourd/ | pH, maximum elevation, drainage |

Brinjal direct fetches timed out, but DOA indexed page text verified its existing
rules. Luffa and snake gourd were verified through indexed DOA page text.
Attempts to retrieve beans, beetroot, radish and cucumber directly were
unsuccessful; they were not added. No third-party crop rules were substituted.

## Suitability and workflow

The original evaluator treated no conflicts as eligible even without enough
evidence, applied drainage to every crop, and asked Gemini to rank all three.
Now drainage is per record. Every supplied known screening rule is evaluated;
missing inputs for known rules prevent eligibility. At least one temperature,
pH, elevation or explicit zone rule must match. This minimum-evidence policy is
an application policy, not a DOA agronomic claim. Soil preference and seasonal
overlap support reasons/ranking but do not establish environmental suitability
alone. Known conflicts produce `UNSUITABLE`; unresolved data/evidence produces
`INSUFFICIENT_EVIDENCE`. Eligible rows remain `CONDITIONAL` for API compatibility.

Gemini still plans, requests all allowed evidence, orders all eligible IDs and
reviews the ranking. Deterministic validation runs again before returning up to
three rows. Exclusions are enforced before lookup; unknown/duplicate IDs are
rejected. `tool_results` preserves assessments for every allowed candidate;
Flutter displays conflicts and evidence gaps alongside results. When none are
eligible, recoverable missing farm inputs yield `NEEDS_INPUT`; otherwise the
result is `NO_MATCH` with `NO_SUITABLE_CROPS`. Excluding all crops returns
`ALL_CROPS_EXCLUDED` without needing a provider. Provider failures return
`FAILED` and empty recommendations. Saved JSON analyses remain unchanged.

## Evidence limits

- `null` means explicitly unknown or not safely expressible with current inputs.
- Optimum/best numerical ranges conservatively screen the shortlist. An outside
  value does not establish that cultivation is impossible.
- Monthly rainfall and humidity have no verified numerical rules in this
  catalog. Chilli annual rainfed rainfall cannot be converted into monthly limits.
- Cabbage/carrot cool-climate wording supplies no numerical temperature rule.
- Tomato optimum elevation is not treated as a universal cultivation boundary.
- Pumpkin elevation guidance is zone-specific; current inputs do not identify
  dry/intermediate zones. Bitter gourd elevation wording is ambiguous. Neither
  becomes a universal cutoff.
- Months represent typical overlap, not hard exclusions or complete dates.
  Nursery dates and named seasons are not converted to field planting months.
- Water availability, local zone/variety suitability, fertility, rotation, pests,
  yield and profit require further assessment.

## Verification and manual checks

Automated Python tests: `.venv/Scripts/python.exe -m unittest test_farmer_ai -v`
from `SmartAgri.Agent`. Focused ASP.NET tests: filter `FarmAiCatalogTests` in
`SmartAgri.Api.Tests`. Flutter: `flutter test test/farmer_ai_catalog_test.dart`;
analyze the changed screen, service and test.

The full ASP.NET test project currently fails to compile because the unrelated
`PackageImagesTests.cs` omits the new `httpClientFactory` constructor argument.
The five Farm AI tests were run through an isolated temporary test project.
No tests here call the database or a live Gemini service.

Manual checks (use a disposable test database because submission saves analyses):

1. Rebuild/restart local API and agent with existing configuration. Sign in as a
   farmer. Confirm 10 exclusion choices; open an older saved analysis in History.
2. With drainage true, temperature 23 C, pH 5.7, elevation 100 m and upcountry wet
   false, analyze. Confirm at most three rows and source-based reasons/checks.
3. Exclude every crop except tomato. Confirm one row. Exclude all crops and
   confirm `ALL_CROPS_EXCLUDED` and no recommendations.
4. Keep only chilli; change temperature from 23 to 35 C. Confirm it leaves the
   shortlist. Keep only luffa; change elevation from 100 to 600 m. Confirm conflict.
5. Set drainage false: confirm no recommendations. Leave known inputs unknown:
   confirm `NEEDS_INPUT`. Keep only carrot with drainage true: confirm evidence
   insufficiency and `NO_MATCH` without a fabricated climate rule.
6. Simulate provider unavailability in the test environment. Confirm `FAILED`,
   empty recommendations and retained failed trace, never a fixed shortlist.
7. Check narrow-screen scrolling, exclusion chips, single-result rendering and
   History. Confirm farmer authentication still protects catalog/analysis routes.

No database records were modified, secrets displayed, commits pushed or services
deployed during this change. Live provider integration remains a manual check.
