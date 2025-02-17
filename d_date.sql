--Adaptado de https://medium.com/@duffn/creating-a-date-dimension-table-in-postgresql-af3f8e2941ac

DROP TABLE if exists d_date;

CREATE TABLE d_date
(
  date_dim_id              INT NOT NULL,
  date_actual              DATE NOT NULL,
  epoch                    BIGINT NOT NULL,
  day_suffix               VARCHAR(4) NOT NULL,
  day_name                 VARCHAR(9) NOT NULL,
  day_of_week              INT NOT NULL,
  day_of_month             INT NOT NULL,
  day_of_quarter           INT NOT NULL,
  day_of_year              INT NOT NULL,
  week_of_month            INT NOT NULL,
  week_of_year             INT NOT NULL,
  week_of_year_iso         CHAR(10) NOT NULL,
  month_actual             INT NOT NULL,
  month_name               VARCHAR(9) NOT NULL,
  month_name_abbreviated   CHAR(3) NOT NULL,
  quarter_actual           INT NOT NULL,
  quarter_name             VARCHAR(9) NOT NULL,
  year_actual              INT NOT NULL,
  first_day_of_week        DATE NOT NULL,
  last_day_of_week         DATE NOT NULL,
  first_day_of_month       DATE NOT NULL,
  last_day_of_month        DATE NOT NULL,
  first_day_of_quarter     DATE NOT NULL,
  last_day_of_quarter      DATE NOT NULL,
  first_day_of_year        DATE NOT NULL,
  last_day_of_year         DATE NOT NULL,
  mmyyyy                   CHAR(6) NOT NULL,
  mmddyyyy                 CHAR(10) NOT NULL,
  weekend_indr             BOOLEAN NOT NULL
);


ALTER TABLE public.d_date ADD CONSTRAINT d_date_date_dim_id_pk PRIMARY KEY (date_dim_id);

CREATE INDEX d_date_date_actual_idx
  ON d_date(date_actual);

COMMIT;

INSERT INTO d_date
SELECT TO_CHAR(datum,'yyyymmdd')::INT AS date_dim_id,
       datum AS date_actual,
       EXTRACT(epoch FROM datum) AS epoch,
       TO_CHAR(datum,'fmDDth') AS day_suffix,
       TO_CHAR(datum,'Day') AS day_name,
       EXTRACT(isodow FROM datum) AS day_of_week,
       EXTRACT(DAY FROM datum) AS day_of_month,
       datum - DATE_TRUNC('quarter',datum)::DATE +1 AS day_of_quarter,
       EXTRACT(doy FROM datum) AS day_of_year,
       TO_CHAR(datum,'W')::INT AS week_of_month,
       EXTRACT(week FROM datum) AS week_of_year,
       TO_CHAR(datum,'YYYY-WIW-') || EXTRACT(isodow FROM datum) AS week_of_year_iso,
       EXTRACT(MONTH FROM datum) AS month_actual,
       TO_CHAR(datum,'Month') AS month_name,
       TO_CHAR(datum,'Mon') AS month_name_abbreviated,
       EXTRACT(quarter FROM datum) AS quarter_actual,
       CASE
         WHEN EXTRACT(quarter FROM datum) = 1 THEN 'First'
         WHEN EXTRACT(quarter FROM datum) = 2 THEN 'Second'
         WHEN EXTRACT(quarter FROM datum) = 3 THEN 'Third'
         WHEN EXTRACT(quarter FROM datum) = 4 THEN 'Fourth'
       END AS quarter_name,
       EXTRACT(isoyear FROM datum) AS year_actual,
       datum +(1 -EXTRACT(isodow FROM datum))::INT AS first_day_of_week,
       datum +(7 -EXTRACT(isodow FROM datum))::INT AS last_day_of_week,
       datum +(1 -EXTRACT(DAY FROM datum))::INT AS first_day_of_month,
       (DATE_TRUNC('MONTH',datum) +INTERVAL '1 MONTH - 1 day')::DATE AS last_day_of_month,
       DATE_TRUNC('quarter',datum)::DATE AS first_day_of_quarter,
       (DATE_TRUNC('quarter',datum) +INTERVAL '3 MONTH - 1 day')::DATE AS last_day_of_quarter,
       TO_DATE(EXTRACT(isoyear FROM datum) || '-01-01','YYYY-MM-DD') AS first_day_of_year,
       TO_DATE(EXTRACT(isoyear FROM datum) || '-12-31','YYYY-MM-DD') AS last_day_of_year,
       TO_CHAR(datum,'mmyyyy') AS mmyyyy,
       TO_CHAR(datum,'mmddyyyy') AS mmddyyyy,
       CASE
         WHEN EXTRACT(isodow FROM datum) IN (6,7) THEN TRUE
         ELSE FALSE
       END AS weekend_indr
-- Sabemos que la tabla empieza en 2009-01-01 y termina en 2013-12-22
FROM (SELECT '2009-01-01'::DATE+ SEQUENCE.DAY AS datum
      FROM GENERATE_SERIES (0,1816) AS SEQUENCE (DAY)
      GROUP BY SEQUENCE.DAY) DQ
ORDER BY 1;

COMMIT;

--Busqueda
SELECT * FROM d_date, Invoice, InvoiceLine WHERE d_date.date_actual=Invoice.InvoiceDate AND Invoice.InvoiceId=InvoiceLine.InvoiceId;

--Vista materializada
CREATE MATERIALIZED VIEW analisis
AS
SELECT dd.week_of_year as semana, dd.month_actual as mes, dd.quarter_actual as trimestre, dd.year_actual as anio,
	i.BillingCountry as pais, i.BillingCity as ciudad,
	mt.Name as audio,
	gn.Name as genero,
	SUM(il.Quantity) as cant
FROM d_date dd, Invoice i, InvoiceLine il, Track tr, MediaType mt, Genre gn
WHERE dd.date_actual=i.InvoiceDate
	AND i.InvoiceId=il.InvoiceId
	AND il.TrackId=tr.TrackId
	AND mt.MediaTypeId=tr.MediaTypeId
	AND gn.GenreId=tr.GenreId
GROUP BY CUBE(semana,mes,trimestre,anio,pais,ciudad,audio,genero)
WITH DATA;

-- Audio mas vendido
SELECT audio, cant
FROM analisis
WHERE semana is null
	AND mes is null
	AND trimestre is null
	and anio is null
	and pais is null
	and ciudad is null
	and genero is null
	and audio is not null
order by cant desc limit 1;

-- genero mas vendido 2013
SELECT genero, cant
FROM analisis
WHERE semana is null
	AND mes is null
	AND trimestre is null
	and anio = 2013
	and pais is null
	and ciudad is null
	and genero is not null
	and audio is null
order by cant desc limit 1;

--Evolucion semanal 2012
SELECT semana, cant
FROM analisis
WHERE semana is not null
	AND mes is null
	AND trimestre is null
	and anio = 2012
	and pais is null
	and ciudad is null
	and genero is null
	and audio is null
order by semana asc;

-- mejor trimestre, por anio
SELECT trimestre, anio, cant
FROM analisis
WHERE semana is null
	AND mes is null
	AND trimestre is not null
	and anio is not null
	and pais is null
	and ciudad is null
	and genero is null
	and audio is null
order by anio asc, cant desc;
