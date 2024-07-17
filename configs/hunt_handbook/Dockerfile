FROM squidfunk/mkdocs-material

RUN apk add --update-cache \
  py3-pip \ 
  py3-pillow \
  py3-cffi \
  py3-brotli \
  gcc \
  musl-dev \
  python3-dev \
  pango

RUN pip install --no-cache-dir \
  mkdocs-awesome-pages-plugin \
  mkdocs-minify-plugin \
  mkdocs-git-revision-date-localized-plugin \
  mkdocs-bibtex \
  mkdocs-img2fig-plugin \
  mkdocs-mermaid2-plugin \
  mkdocs-pdf-export-plugin

ENTRYPOINT ["mkdocs"]

CMD [ "build"]