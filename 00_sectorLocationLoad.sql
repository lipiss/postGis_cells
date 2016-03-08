DROP TABLE IF EXISTS sector_location_csv;
CREATE TABLE sector_location_csv 
(
utrancellid varchar,
subnetwork varchar,
enodeb varchar,
gcid varchar,
TECHNOLOGY varchar,
LATITUDE double precision,
LONGITUDE double precision, 
AZIMUTH int,
uarfcndl double precision
);
COPY sector_location_csv FROM 'c:\temp\0000 sector.csv' WITH (FORMAT csv, DELIMITER ',',  NULL 'NULL', HEADER);
--utrancellid,subnetwork,enodeb,gcid,TECHNOLOGY,LATITUDE,LONGITUDE,AZIMUTH,uarfcndl
DROP TABLE IF EXISTS sector_location_geometries;
--CREATE TABLE geometries (name varchar, geom geometry);
CREATE TABLE sector_location_geometries AS 
SELECT
utrancellid,
azimuth,
enodeb,
ST_MakePoint(longitude,latitude),
ST_MakePolygon(
ST_MakeLine(
ARRAY[
ST_AsText(ST_MakePoint(longitude,latitude)),
ST_AsText(ST_Project(ST_MakePoint(longitude,latitude)::geography, 100, radians((azimuth-30+360)%360))),
ST_AsText(ST_Project(ST_MakePoint(longitude,latitude)::geography, 100, radians((azimuth+30)%360))),
ST_AsText(ST_MakePoint(longitude,latitude))
]))
FROM
sector_location_csv;
/* Geometry example - units in meters (SRID: 26986 Massachusetts state plane meters) (most accurate for Massachusetts) */
DROP TABLE IF EXISTS distance;
CREATE TABLE distance AS
SELECT 
s1.utrancellid as utrancellid_s1,
ST_SetSRID(ST_MakePoint(s1.longitude, s1.latitude), 4326) as point_s1,
s2.utrancellid as utrancellid_s2,
ST_SetSRID(ST_MakePoint(s2.longitude, s2.latitude), 4326) as point_s2,
ST_Distance(
ST_Transform(ST_SetSRID(geometry(ST_MakePoint(s1.longitude, s1.latitude)::geography), 4326),26986),
ST_Transform(ST_SetSRID(geometry(ST_MakePoint(s2.longitude, s2.latitude)::geography), 4326),26986)) as distance_meters
FROM 
public.sector_location_csv s1,
public.sector_location_csv s2
where 
s1.longitude<>0 and s1.longitude<>0 
and 
s2.longitude<>0 and s2.latitude <>0
and
ST_Distance(
ST_Transform(ST_SetSRID(geometry(ST_MakePoint(s1.longitude, s1.latitude)::geography), 4326),26986),
ST_Transform(ST_SetSRID(geometry(ST_MakePoint(s2.longitude, s2.latitude)::geography), 4326),26986)
)<=10;

/*Remove duplicate combinations using: select distinct on order by. The field utrancellid_s2 will be group id.*/
SELECT DISTINCT
ON (utrancellid_s1) utrancellid_s1,
utrancellid_s2
FROM
distance
ORDER BY
utrancellid_s1,
utrancellid_s2;
DROP TABLE IF EXISTS sectorCount;
CREATE TABLE sectorCount AS
SELECT
utrancellid_s2,
COUNT(utrancellid_s2) as sectorCount,
point_s2
FROM
(
        SELECT DISTINCT
        ON (utrancellid_s1) utrancellid_s1,
        utrancellid_s2,
        point_s2
        FROM
        distance
        ORDER BY
        utrancellid_s1,
        utrancellid_s2
) T
GROUP BY
utrancellid_s2,point_s2;

DROP TABLE IF EXISTS concave_noParam;
CREATE TABLE concave_noParam AS
SELECT 
ST_ConcaveHull(ST_Collect(ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)),1) As the_geom
FROM public.sector_location_csv As d
where longitude<>0
GROUP BY subnetwork;

DROP TABLE IF EXISTS concave_090;
CREATE TABLE concave_090 AS
SELECT 
ST_ConcaveHull(ST_Collect(ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)),0.90) As the_geom
FROM public.sector_location_csv As d
where longitude<>0
GROUP BY subnetwork;

DROP TABLE IF EXISTS concave_095;
CREATE TABLE concave_095 AS
SELECT 
ST_ConcaveHull(ST_Collect(ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)),0.95) As the_geom
FROM public.sector_location_csv As d
where longitude<>0
GROUP BY subnetwork;

DROP TABLE IF EXISTS concave_095_true;
CREATE TABLE concave_095_true AS
SELECT 
ST_ConcaveHull(ST_Collect(ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)),0.95,true) As the_geom
FROM public.sector_location_csv As d
where longitude<>0
GROUP BY subnetwork;

DROP TABLE IF EXISTS concave_098_true;
CREATE TABLE concave_098_true AS
SELECT 
ST_ConcaveHull(ST_Collect(ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)),0.98,true) As the_geom
FROM public.sector_location_csv As d
where longitude<>0
GROUP BY subnetwork;

DROP TABLE IF EXISTS concave_099_false;
CREATE TABLE concave_099_false AS
SELECT 
subnetwork,
ST_Area(ST_Transform(ST_ConcaveHull(ST_Collect(ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)),0.99,true),26986))/POW(10,6) as sqrkm,
ST_ConcaveHull(ST_Collect(ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)),0.99,true) As the_geom
FROM public.sector_location_csv As d
where longitude<>0
GROUP BY subnetwork;
ALTER TABLE concave_099_false ADD COLUMN nocells INT;
UPDATE concave_099_false
SET nocells=x.countu
FROM
(
    SELECT
    subnetwork,
    COUNT(utrancellid) as countu
    FROM
    sector_location_csv
    GROUP BY subnetwork
) as x
where concave_099_false.subnetwork = x.subnetwork;


DROP FUNCTION IF EXISTS create_polygon_for_each_subnetwork(queries text, target_percent text, step int);
/*This functions creates a layer for each uarfcndl. For each sector a semi circle is created, the radius will depend on the uarfcndl*/
--/
CREATE FUNCTION create_polygon_for_each_subnetwork(tableName text, target_percent text, step int) RETURNS VOID AS $dbvis$
DECLARE
    i text;
    query text;
BEGIN

    FOR i in EXECUTE 'SELECT distinct subnetwork FROM sector_location_csv ORDER BY 1 ASC'
    LOOP
        EXECUTE 'DROP TABLE IF EXISTS ' || tableName || i;
        SELECT 'CREATE TABLE ' || tableName ||i || 
        ' AS SELECT
        ''' ||i||''' as subnetwork,
        ST_ConcaveHull(ST_Collect(ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)),'||target_percent||',true) As subnetworkPolygon,
        ST_Buffer(ST_Transform(
        ST_ConcaveHull(ST_Collect(ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)),'||target_percent||',true)
        ,26986),-1000)::geometry(Polygon,26986) As subnetworkPolygonbuffer /*introduces -1000m of buffer*/
        FROM public.sector_location_csv As d
        where LONGITUDE<>0 or LATITUDE<>0
        GROUP BY subnetwork HAVING subnetwork=''' ||i||'''' into query;
        EXECUTE query;
    END LOOP;
--RETURN 1;
END;
$dbvis$ LANGUAGE plpgsql
/

SELECT * from create_polygon_for_each_subnetwork('subnetwork_polygon_','0.99',20);
