CREATE TABLE artist (
    id         BIGSERIAL PRIMARY KEY,
    name       VARCHAR(120) NOT NULL,
    country    VARCHAR(60),
    genre     VARCHAR(40)
);

CREATE TABLE album (
    id         BIGSERIAL PRIMARY KEY,
    title      VARCHAR(150) NOT NULL,
    release_year        INT,
    artist_id  BIGINT NOT NULL REFERENCES artist(id)
);

CREATE TABLE music (
    id                BIGSERIAL PRIMARY KEY,
    title             VARCHAR(150) NOT NULL,
    seconds_duration  INT,
    reproductions     BIGINT,
    release_date      DATE,
    album_id          BIGINT NOT NULL REFERENCES album(id)
);