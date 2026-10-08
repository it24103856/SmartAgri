import importlib
import unittest


def selected_suite(loader, selections):
    suite = unittest.TestSuite()
    for module_name, class_name, method_names in selections:
        module = importlib.import_module(module_name)
        for method_name in method_names:
            suite.addTest(loader.loadTestsFromName(
                f"{module.__name__}.{class_name}.{method_name}"
            ))
    return suite
