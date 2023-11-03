# Before Every Commit

1. Run `mix text` - fix any failing tests
2. Run `mix compile`
3. Any others?

# Commit Message Semantics

See how a minor change to your commit message style can make you a better programmer.

Format: `<type>(<scope>): <subject>`

`<scope>` is optional

## Example

```
feat frontend: add hat wobble
^--^  ^------------^
|     |
|     +-> Summary in present tense.
|
+-------> Type: chore, docs, feat, fix, refactor, style, or test.
```

More Examples:

- `feat frontend`: (new frontend feature for the user, not a new feature for build script)
- `feat backend`: (new backend feature for the user, not a new feature for build script)
- `feat`: (new fullstack feature for the user, not a new feature for build script)

&nbsp;


- `nit frontend`: (minor frontend change)
- `nit backend`: (minor backend change)
- `nit`: (minor fullstack change)

&nbsp;


- `fix frontend`: (frontend bug fix for the user, not a fix to a build script)
- `fix backend`: (backend bug fix for the user, not a fix to a build script)
- `fix`: (fullstack bug fix)

&nbsp;


- `style frontend`: (frontend formatting, missing semi colons, etc; no production code change)
- `style backend`: (backend formatting, missing semi colons, etc; no production code change)
- `style`: (fullstack formatting, missing semi colons, etc; no production code change)

&nbsp;


- `refactor frontend`: (refactoring production frontend code, eg. renaming a variable)
- `refactor backend`: (refactoring production backend code, eg. renaming a variable)
- `refactor`: (refactoring production fullstack code, eg. renaming a variable)

&nbsp;


- `test frontend`: (adding missing frontend tests, refactoring tests; no production code change)
- `test backend`: (adding missing backend tests, refactoring tests; no production code change)
- `test db`: (adding missing db tests, refactoring tests; no production code change)

&nbsp;


- `chore`: (updating grunt tasks etc; no production code change)

&nbsp;


- `docs`: (changes to the documentation)