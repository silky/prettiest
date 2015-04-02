
default: blog.html

# %.html: %.org
# pandoc --email-obfuscation=references --smart --standalone --css=home.css --from=org --to=html --output=$@ $<

%.html: %.md
	pandoc --email-obfuscation=references --smart --standalone --css=home.css --from=markdown --to=html --output=$@ $<

%.md: %.org
	pandoc --from=org --to=markdown --output=$@ $<