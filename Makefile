# Variables
SOURCE_DIR = drafts
BUILD_DIR = generated
SOURCES = $(wildcard $(SOURCE_DIR)/*.md)
# This creates a list of targets based on filenames in the drafts folder
TARGETS = $(patsubst $(SOURCE_DIR)/%.md, %, $(SOURCES))

.PHONY: all clean $(TARGETS)

all: $(TARGETS)

$(TARGETS):
	@echo "-------------------------------------------------------"
	@echo "Processing draft: $@"
	@echo "-------------------------------------------------------"
	# Create or refresh the specific output directory
	rm -rf $(BUILD_DIR)/$@
	mkdir -p $(BUILD_DIR)/$@
	
	# Generate XML from Markdown
	kramdown-rfc $(SOURCE_DIR)/$@.md > $(BUILD_DIR)/$@/$@.xml
	
	# Generate Text and HTML from XML
	xml2rfc $(BUILD_DIR)/$@/$@.xml --text --html --pdf --path $(BUILD_DIR)/$@/
	
	@echo "Done! Files available in $(BUILD_DIR)/$@/"

clean:
	rm -rf $(BUILD_DIR)
	@echo "Cleaned generated files."
