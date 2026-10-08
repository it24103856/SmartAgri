from _suites import selected_suite


def load_tests(loader, tests, pattern):
    return selected_suite(loader, [
        (
            "test_basket_fallback",
            "ProviderFallbackTests",
            [
                "test_reported_trailing_comma_request_succeeds_after_503",
                "test_503_exhausts_three_attempts_then_returns_local_plan",
                "test_actual_provider_message_is_logged_before_fallback",
                "test_bad_request_falls_back_without_retry_but_programming_errors_do_not",
            ],
        ),
    ])
