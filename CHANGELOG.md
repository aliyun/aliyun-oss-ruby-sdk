## Change Log

### v0.1.7

- Fix StreamWriter#inspect bug
- Fix wrong in README

### v0.1.6

- Required ruby version >= 1.9.3 due to 1.9.2 has String encoding
  compatibility problems
- Add travis & overalls
- Open source to github.com

### v0.1.5

- Add open_timeout and read_timeout config
- Fix a concurrency bug in resumable_upload/download

### v0.1.4

- Fix object key encoding problem
- Fix Content-Type problem
- Add list_uploads & abort_uploads methods
- Make resumable_upload/download faster by multi-threading
- Enable log rotate

### v0.1.3

- Include request id in exception message

### v0.1.2

- Fix yard doc unresolved link

### v0.1.1

- Add README.md CHANGELOG.md in gem
