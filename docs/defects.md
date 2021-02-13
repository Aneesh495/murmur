# Defect ledger

Each behavioral defect found during development is tied to a regression that
failed before its repair. Syntax and module-load errors are caught by the suite's
mandatory load of every test and its referenced implementation modules.

## R001: dynamically resolved record accessor

The initial source-redaction test failed with `Wrong type to apply` because a
Guile SRFI-9 accessor obtained through `module-ref` was a syntax transformer.
Importing the buffer interface directly allows Guile to expand the accessor.
`replacement noninterference` failed before the repair and now exercises all
three replacement modes over every sample in both channels.
