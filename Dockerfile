FROM dmstraub/gramps:5.1.5

ENV GRAMPS_VERSION=51
WORKDIR /app
ENV PYTHONPATH="${PYTHONPATH}:/usr/lib/python3/dist-packages"

# install poppler (needed for PDF thumbnails)
# ffmpeg (needed for video thumbnails)
# postgresql client (needed for PostgreSQL backend)
RUN apt-get update && apt-get install -y \
  poppler-utils ffmpeg libavcodec-extra \
  unzip \
  libpq-dev postgresql-client postgresql-client-common python3-psycopg2 \
  libgl1-mesa-dev libgtk2.0-dev libatlas-base-dev \
  libopencv-dev python3-opencv \
  && rm -rf /var/lib/apt/lists/*

# set locale
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANGUAGE en_US.utf8
ENV LANG en_US.utf8
ENV LC_ALL en_US.utf8

ENV GRAMPS_API_CONFIG=/app/config/config.cfg

# create directories
RUN mkdir /app/src &&  mkdir /app/config && touch /app/config/config.cfg
RUN mkdir /app/static && touch /app/static/index.html
RUN mkdir /app/db && mkdir /app/media && mkdir /app/indexdir && mkdir /app/users
RUN mkdir /app/thumbnail_cache
RUN mkdir /app/cache && mkdir /app/cache/reports && mkdir /app/cache/export
RUN mkdir /app/tmp && mkdir /app/persist
RUN mkdir -p /root/.gramps/gramps$GRAMPS_VERSION
# set config options
ENV GRAMPSWEB_USER_DB_URI=sqlite:////app/users/users.sqlite
ENV GRAMPSWEB_MEDIA_BASE_DIR=/app/media
ENV GRAMPSWEB_SEARCH_INDEX_DIR=/app/indexdir
ENV GRAMPSWEB_STATIC_PATH=/app/static
ENV GRAMPSWEB_THUMBNAIL_CACHE_CONFIG__CACHE_DIR=/app/thumbnail_cache
ENV GRAMPSWEB_REPORT_DIR=/app/cache/reports
ENV GRAMPSWEB_EXPORT_DIR=/app/cache/export

# install PostgreSQL addon
RUN wget https://github.com/gramps-project/addons/archive/refs/heads/master.zip \
    && unzip -p master.zip addons-master/gramps$GRAMPS_VERSION/download/PostgreSQL.addon.tgz | \
    tar -xvz -C /root/.gramps/gramps$GRAMPS_VERSION/plugins \
    && unzip -p master.zip addons-master/gramps$GRAMPS_VERSION/download/SharedPostgreSQL.addon.tgz | \
    tar -xvz -C /root/.gramps/gramps$GRAMPS_VERSION/plugins \
    && rm master.zip

# install gunicorn
RUN python3 -m pip install --no-cache-dir --extra-index-url https://www.piwheels.org/simple \
    gunicorn

# install dependecies
RUN python3 -m pip install --no-cache-dir --extra-index-url https://www.piwheels.org/simple \
    "Click>=7.0" "Flask>=2.1.0" "Flask-Caching>=2.0.0" Flask-Compress Flask-Cors "Flask-Limiter>=2.9.0" Flask-SQLAlchemy "marshmallow>=3.13.0" webargs SQLAlchemy pdf2image Pillow "bleach>=5.0.0" tinycss2 whoosh jsonschema ffmpeg-python alembic "celery[redis]" Unidecode

# copy package source and install
COPY . /app/src
RUN python3 -m pip install --no-cache-dir --extra-index-url https://www.piwheels.org/simple \
    /app/src

EXPOSE 5000

COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD gunicorn -w ${GUNICORN_NUM_WORKERS:-8} -b 0.0.0.0:5000 gramps_webapi.wsgi:app --timeout 120 --limit-request-line 8190
