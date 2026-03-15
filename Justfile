set windows-powershell := true

# Show this help
@help:
  just --list

# Install jekyll and friends
install:
  bundle install

# Run dev server
serve:
  bundle exec jekyll serve --watch --drafts --unpublished --future --open-url -P 0 --livereload

# Create a draft from a template
[script]
start-draft TITLE:
  test ! -e _drafts/{{TITLE}}.md
  cat > _drafts/{{TITLE}}.md <<EOF
  ---
  layout: post-text
  title: {{TITLE}}
  tags: 
  excerpt_separator: <!--more-->
  ---
  EOF
  echo Draft created at _drafts/{{TITLE}}.md

# Move a draft to publish, using today's date
publish-draft TITLE:
  mv -n _drafts/{{TITLE}}.md _posts/$(date +%F)-{{TITLE}}.md
