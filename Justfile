set windows-powershell := true

# Show this help
@help:
  just --list

install:
  bundle install

serve:
  bundle exec jekyll serve
