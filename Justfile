set windows-powershell := true

# Show this help
@help:
  just --list

install:
  bundle install

serve:
  bundle exec jekyll serve

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

publish-draft TITLE:
  mv -n _drafts/{{TITLE}}.md _posts/$(date +%F)-{{TITLE}}.md
