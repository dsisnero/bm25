.PHONY: all clean check format lint test

all: check

clean:
	rm -rf ./temp/*

format:
	crystal tool format --check src spec

lint:
	ameba src spec

test:
	crystal spec

check: format lint test
	@echo "All checks passed."
