FROM pandoc/latex:latest


RUN apk update && apk add --no-cache \
  bash \
  jq \
  lua5.4 \
  lua5.4-dev \
  luarocks \
  build-base \
  unzip \
  curl \
  git \
  nodejs \
  npm \
  tar

  RUN apk add --no-cache ghc cabal

  RUN cabal update && cabal install pandoc-sidenote

ENV PATH="/root/.local/bin:${PATH}"

COPY . /mdConverter

# install de dkjson dans le container sans luarocks
RUN curl -o dkjson.lua https://raw.githubusercontent.com/LuaDist/dkjson/master/dkjson.lua \
  && mv dkjson.lua /mdConverter/filter/dkjson.lua


WORKDIR /ARTIFACTS

RUN chmod +x /mdConverter/convert_pdf.sh

ENTRYPOINT ["/mdConverter/convert_pdf.sh"]
