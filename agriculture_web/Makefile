RUNNER = node test/runner.mjs
ALL_TESTS = src/pages/Analytics/salesReport.test.js \
	src/pages/Categories/categoryUtils.test.js \
	src/pages/Products/productUtils.test.js \
	src/pages/Orders/orderUtils.test.js \
	src/pages/Packages/packageUtils.test.js \
	src/pages/Users/userUtils.test.js \
	src/pages/SmartBaskets/smartBasketUtils.test.js

.PHONY: help test test-member1 test-member2 test-member3 test-member4 web-install

help:
	@$(RUNNER) --help

test:
	@$(RUNNER) --title "Web dashboard" --subtitle "All frontend tests" --files $(ALL_TESTS)

test-member1:
	@$(RUNNER) --title "Member 1" --subtitle "Categories and Products" --files src/pages/Categories/categoryUtils.test.js src/pages/Products/productUtils.test.js

test-member2:
	@$(RUNNER) --title "Member 2" --subtitle "Orders" --files src/pages/Orders/orderUtils.test.js

test-member3:
	@$(RUNNER) --title "Member 3" --subtitle "Analytics and Dashboard" --files src/pages/Analytics/salesReport.test.js

test-member4:
	@$(RUNNER) --title "Member 4" --subtitle "Packages, Users and Smart Baskets" --files src/pages/Packages/packageUtils.test.js src/pages/Users/userUtils.test.js src/pages/SmartBaskets/smartBasketUtils.test.js

web-install:
	npm ci
