PYTHON ?= python
RUNNER = node test/runner.mjs

.PHONY: help test-member1 test-member2 test-member3 test-member4 test-agent

help:
	@echo "make test-member1  CatalogAgent and Validator"
	@echo "make test-member2  PlannerAgent"
	@echo "make test-member3  BasketAgent"
	@echo "make test-member4  ReviewAgent"
	@echo "make test-agent    All Python Agent tests"

test-member1:
	$(RUNNER) --title "Member 1" --subtitle "CatalogAgent and Validator" --pattern "test_catalog_validator.py" --python "$(PYTHON)"

test-member2:
	$(RUNNER) --title "Member 2" --subtitle "PlannerAgent" --pattern "test_planner.py" --python "$(PYTHON)"

test-member3:
	$(RUNNER) --title "Member 3" --subtitle "BasketAgent" --pattern "test_basket.py" --python "$(PYTHON)"

test-member4:
	$(RUNNER) --title "Member 4" --subtitle "ReviewAgent" --pattern "test_review.py" --python "$(PYTHON)"

test-agent:
	$(RUNNER) --title "All Python Agents" --subtitle "Catalog, Planner, Basket and Review" --pattern "test_*.py" --python "$(PYTHON)"
