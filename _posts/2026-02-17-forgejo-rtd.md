---
layout: post-text
title: Read the Docs and Forgejo/Codeberg
tags: docs, forgejo, devops
---

Read the Docs and Sphinx? Really good. 10/10. Recommend for everything.

GitHub? In the Fucking Around phase.

Codeberg? Good enough.

So let's glue some things together.

## With more words

Microsoft/GitHub is making unpleasant and distasteful choices, and I would like off the ride please. Forgejo and Codeberg are currently a reasonable alternative--they're big weakness is CI/CD, but otherwise I find Codeberg solid for my open source work.

I really like using Read the Docs. (Even with my own [Teahouse Hosting](https://teahouse.cafe/), RTD has value-add.) But it doesn't (yet) have a native integration with Forgejo.

But! I recently published [Handtruck](https://pypi.org/project/handtruck) and its [docs](https://handtruck.readthedocs.io/) from Codeberg, so let's discuss out.

### On Forgejo & Codeberg

For those that aren't familiar:

A "forge" is a code host, usually also offering issue tracking, code review, CI/CD, and other features needed to develop software. GitHub, BitBucket, GitLab, sourcehut, etc.

[Forgejo](https://forgejo.org/) is open source forge software. It was forked from Gitea (which was forked from Gogs), and is lighter weight than other forge options. There are many Forgejo instances.

[Codeberg](https://codeberg.org/) is a non-profit organization and managed Forgejo instance, focusing exclusively on supporting open source.

While this blog post documents what I did on Codeberg, I believe it'll work with minimal modification on other Forgejo instances.

## Preparing the Repo

You still need a [`.readthedocs.yaml`](https://docs.readthedocs.io/en/stable/config-file/v2.html) inside your repo. The usual versions will work.

Oh, and you need a Sphinx site. I keep mine in `docs`, but you do you.

### Poetry aside

I rather like using Poetry for my depedency management, although you can probably adapt this section to other tools.

I keep docs-specific dependencies in a `docs` depdency group, which is distinct from the `dev` group and the package dependencies Read the Docs can only use `requirements.txt` for environment setup. So as part of my `pre_create_environment` job, I generate it:

```yaml
build:
  jobs:
    pre_create_environment:
      # (Be sure to set up poetry before this)
      - /home/docs/.local/bin/poetry export --with=docs | tee docs/requirements.txt
```

and then you can tell the RTD builder to use it:

```yaml
python:
   install:
   - requirements: docs/requirements.txt
   - method: pip
     path: .
```

The handtruck source has the [full config file](https://codeberg.org/teahouse/handtruck/src/branch/trunk/.readthedocs.yaml).

### Justfile aside

Lukewarm take: [Just](https://just.systems/) is better than Make for project tasks. You should be using it.

I've gotten into the habbit of replacing the `Makefile` and `make.bat` files in my Sphinx projects with a `Justfile`--it's got more flexibility, and you can do platform shenanigans without second files.

This is Handtruck's. You probably want to customize the use of Poetry and the `--watch` flag.

```justfile
set windows-powershell := true
set fallback

SPHINXOPTS    := ""
SOURCEDIR     := "."
BUILDDIR      := "_build"

# Show this help
@help:
  just --list

# Run sphinx autobuild against the docs.
serve:
  poetry run sphinx-autobuild --nitpicky --port 0 --open-browser --watch "../src" "{{SOURCEDIR}}" "{{BUILDDIR}}/html"

# Do a sphinx build
build KIND="html":
  poetry run sphinx-build -M {{KIND}} "{{SOURCEDIR}}" "{{BUILDDIR}}" {{SPHINXOPTS}}

# Clean up built files
@clean:
  just build clean
```

Oh, and I use [sphinx-autobuild](https://github.com/sphinx-doc/sphinx-autobuild) as a preview server.

## Connecting Read the Docs to Forgejo

Thankfully, Forgejo's webhooks are close enough to GitHub's that RTD will accept them and execute builds. You don't get build status reported back to Forgejo, but your docs will publish.

Codeberg has a great [tutorial on connecting RTD and Forgejo](https://docs.codeberg.org/integrations/read-the-docs/).

**Note**: You do have to copy the webhook secret from RTD into Forgejo. The tutorial doesn't say this, but it won't work if you don't.

## Automations

At this point, your docs should be building and publishing. I recommend configuring your RTD Automations. "Automation Rules" in the project settings on the Read the Docs admin panel.

The one I'll recommend universally is automatically activating releases:

* Match: Whatever works for you
* Version type: Tag (probably)
* Action: Activate version

This will cause RTD to automatically publish new editions of your docs when you cut a release.

## Customizing Furo

I like the [Furo theme](https://pradyunsg.me/furo/) for Sphinx. Unfortunately, if you're not on GitHub, a bunch of automatic stuff falls off. Namely, the header edit button and the footer source links.

Both can be fixed in `conf.py` in one block (be sure to adjust the URLs for your project):

```python
html_theme_options = {
    "source_edit_link": "https://codeberg.org/teahouse/handtruck/_edit/trunk/docs/{filename}",
    "source_view_link": "https://codeberg.org/teahouse/handtruck/src/branch/trunk/docs/{filename}",
    "footer_icons": [
        {
            "name": "On Read the Docs",
            "url": "https://readthedocs.org/projects/handtruck",
            "html": """
                <svg x="0px" y="0px" viewBox="-125 217 360 360" xml:space="preserve">
                  <path fill="currentColor" d="M39.2,391.3c-4.2,0.6-7.1,4.4-6.5,8.5c0.4,3,2.6,5.5,5.5,6.3 c0,0,18.5,6.1,50,8.7c25.3,2.1,54-1.8,54-1.8c4.2-0.1,7.5-3.6,7.4-7.8c-0.1-4.2-3.6-7.5-7.8-7.4c-0.5,0-1,0.1-1.5,0.2 c0,0-28.1,3.5-50.9,1.6c-30.1-2.4-46.5-7.9-46.5-7.9C41.7,391.3,40.4,391.1,39.2,391.3z M39.2,353.6c-4.2,0.6-7.1,4.4-6.5,8.5 c0.4,3,2.6,5.5,5.5,6.3c0,0,18.5,6.1,50,8.7c25.3,2.1,54-1.8,54-1.8c4.2-0.1,7.5-3.6,7.4-7.8c-0.1-4.2-3.6-7.5-7.8-7.4 c-0.5,0-1,0.1-1.5,0.2c0,0-28.1,3.5-50.9,1.6c-30.1-2.4-46.5-7.9-46.5-7.9C41.7,353.6,40.4,353.4,39.2,353.6z M39.2,315.9 c-4.2,0.6-7.1,4.4-6.5,8.5c0.4,3,2.6,5.5,5.5,6.3c0,0,18.5,6.1,50,8.7c25.3,2.1,54-1.8,54-1.8c4.2-0.1,7.5-3.6,7.4-7.8 c-0.1-4.2-3.6-7.5-7.8-7.4c-0.5,0-1,0.1-1.5,0.2c0,0-28.1,3.5-50.9,1.6c-30.1-2.4-46.5-7.9-46.5-7.9 C41.7,315.9,40.4,315.8,39.2,315.9z M39.2,278.3c-4.2,0.6-7.1,4.4-6.5,8.5c0.4,3,2.6,5.5,5.5,6.3c0,0,18.5,6.1,50,8.7 c25.3,2.1,54-1.8,54-1.8c4.2-0.1,7.5-3.6,7.4-7.8c-0.1-4.2-3.6-7.5-7.8-7.4c-0.5,0-1,0.1-1.5,0.2c0,0-28.1,3.5-50.9,1.6 c-30.1-2.4-46.5-7.9-46.5-7.9C41.7,278.2,40.4,278.1,39.2,278.3z M-13.6,238.5c-39.6,0.3-54.3,12.5-54.3,12.5v295.7 c0,0,14.4-12.4,60.8-10.5s55.9,18.2,112.9,19.3s71.3-8.8,71.3-8.8l0.8-301.4c0,0-25.6,7.3-75.6,7.7c-49.9,0.4-61.9-12.7-107.7-14.2 C-8.2,238.6-10.9,238.5-13.6,238.5z M19.5,257.8c0,0,24,7.9,68.3,10.1c37.5,1.9,75-3.7,75-3.7v267.9c0,0-19,10-66.5,6.6 C59.5,536.1,19,522.1,19,522.1L19.5,257.8z M-3.6,264.8c4.2,0,7.7,3.4,7.7,7.7c0,4.2-3.4,7.7-7.7,7.7c0,0-12.4,0.1-20,0.8 c-12.7,1.3-21.4,5.9-21.4,5.9c-3.7,2-8.4,0.5-10.3-3.2c-2-3.7-0.5-8.4,3.2-10.3c0,0,0,0,0,0c0,0,11.3-6,27-7.5 C-16,264.9-3.6,264.8-3.6,264.8z M-11,302.6c4.2-0.1,7.4,0,7.4,0c4.2,0.5,7.2,4.3,6.7,8.5c-0.4,3.5-3.2,6.3-6.7,6.7 c0,0-12.4,0.1-20,0.8c-12.7,1.3-21.4,5.9-21.4,5.9c-3.7,2-8.4,0.5-10.3-3.2c-2-3.7-0.5-8.4,3.2-10.3c0,0,11.3-6,27-7.5 C-20.5,302.9-15.2,302.7-11,302.6z M-3.6,340.2c4.2,0,7.7,3.4,7.7,7.7s-3.4,7.7-7.7,7.7c0,0-12.4-0.1-20,0.7 c-12.7,1.3-21.4,5.9-21.4,5.9c-3.7,2-8.4,0.5-10.3-3.2c-2-3.7-0.5-8.4,3.2-10.3c0,0,11.3-6,27-7.5C-16,340.1-3.6,340.2-3.6,340.2z" />
                </svg>
            """,
            "class": "",
        },
        {
            "name": "On Codeberg",
            "url": "https://codeberg.org/teahouse/handtruck",
            "html": """
                <svg stroke="currentColor" fill="currentColor" stroke-width="0" role="img" viewBox="0 0 24 24" height="200px" width="200px" xmlns="http://www.w3.org/2000/svg"><path d="M11.955.49A12 12 0 0 0 0 12.49a12 12 0 0 0 1.832 6.373L11.838 5.928a.187.14 0 0 1 .324 0l10.006 12.935A12 12 0 0 0 24 12.49a12 12 0 0 0-12-12 12 12 0 0 0-.045 0zm.375 6.467l4.416 16.553a12 12 0 0 0 5.137-4.213z"></path></svg>
            """,
            "class": "",
        },
    ],
}
```

See the Furo docs:

* [Customizing the source view & edit buttons](https://pradyunsg.me/furo/customisation/top-of-page-buttons/)
* [Customizing the footer icons](https://pradyunsg.me/furo/customisation/footer/)

(The RTD icon came from the Furo docs. The Codeberg icon came from [react-icons](https://react-icons.github.io/react-icons/search/#q=codeberg).)
