DROP FUNCTION IF EXISTS create_uarfcndl_polygons_layers_multiple(queries text, d int, step int);
/*This functions creates a layer for each uarfcndl. For each sector a semi circle is created, the radius will depend on the uarfcndl*/
--/
CREATE FUNCTION create_uarfcndl_polygons_layers_multiple(tableName text, d int, step int) RETURNS VOID AS $dbvis$
DECLARE
    i text;
    query text;
BEGIN

    FOR i in EXECUTE 'SELECT distinct uarfcndl FROM sector_location_csv ORDER BY 1 DESC'
    LOOP
        EXECUTE 'DROP TABLE IF EXISTS ' || tableName || i;
        SELECT 'CREATE TABLE ' || tableName ||i || 
        ' AS SELECT
        utrancellid,
        enodeb,
        subnetwork,
        uarfcndl,
        azimuth,
        ST_MakePoint(longitude,latitude),
        ST_MakePolygon(
        ST_MakeLine(
        ARRAY[
        ST_AsText(ST_MakePoint(longitude,latitude)),
        ST_AsText(ST_Project(ST_MakePoint(longitude,latitude)::geography, $distance, radians((azimuth-30+360)%360))),
        ST_AsText(ST_Project(ST_MakePoint(longitude,latitude)::geography, $distance, radians((azimuth-20+360)%360))),
        ST_AsText(ST_Project(ST_MakePoint(longitude,latitude)::geography, $distance, radians((azimuth-10+360)%360))),
        ST_AsText(ST_Project(ST_MakePoint(longitude,latitude)::geography, $distance, radians((azimuth-0+360)%360))),
        ST_AsText(ST_Project(ST_MakePoint(longitude,latitude)::geography, $distance, radians((azimuth+10+360)%360))),
        ST_AsText(ST_Project(ST_MakePoint(longitude,latitude)::geography, $distance, radians((azimuth+20+360)%360))),
        ST_AsText(ST_Project(ST_MakePoint(longitude,latitude)::geography, $distance, radians((azimuth+30)%360))),
        ST_AsText(ST_MakePoint(longitude,latitude))
        ]))
        FROM
        sector_location_csv WHERE uarfcndl=' ||i into query;
        EXECUTE replace(query,'$distance',cast (d as text));
        d=d+step;
    END LOOP;
--RETURN 1;
END;
$dbvis$ LANGUAGE plpgsql
/

SELECT * from create_uarfcndl_polygons_layers_multiple('uarfcndl_',150,20);

/* Colours: 
#ff0000, red, 
#00ff00, green,
#0000ff, blue,
#ffff00, yellow

*/
DROP FUNCTION IF EXISTS create_uarfcndl_polygons_layers_single(queries text, d int, step int);
/*This functions creates a layer for each uarfcndl. For each sector a semi circle is created, the initial radius will depend on 'd int', then in an increasing order each uarfcndl will be incremented step int*/
--/
CREATE FUNCTION create_uarfcndl_polygons_layers_single(tableName text, d int, step int) RETURNS VOID AS $dbvis$
DECLARE
    i text;
    query text;
BEGIN

        i='';
        EXECUTE 'DROP TABLE IF EXISTS ' || tableName || i;
        SELECT 'CREATE TABLE ' || tableName ||i || 
        ' AS SELECT
        utrancellid,
        subnetwork,
        sector_location_csv.uarfcndl,
        azimuth,
        ST_MakePoint(longitude,latitude),
        ST_MakePolygon(
        ST_MakeLine(
        ARRAY[
        ST_AsText(ST_MakePoint(longitude,latitude)),
        ST_AsText(ST_Project(ST_MakePoint(longitude,latitude)::geography, $distance+steps*10, radians((azimuth-30+360)%360))),
        ST_AsText(ST_Project(ST_MakePoint(longitude,latitude)::geography, $distance+steps*10, radians((azimuth-20+360)%360))),
        ST_AsText(ST_Project(ST_MakePoint(longitude,latitude)::geography, $distance+steps*10, radians((azimuth-10+360)%360))),
        ST_AsText(ST_Project(ST_MakePoint(longitude,latitude)::geography, $distance+steps*10, radians((azimuth-0+360)%360))),
        ST_AsText(ST_Project(ST_MakePoint(longitude,latitude)::geography, $distance+steps*10, radians((azimuth+10+360)%360))),
        ST_AsText(ST_Project(ST_MakePoint(longitude,latitude)::geography, $distance+steps*10, radians((azimuth+20+360)%360))),
        ST_AsText(ST_Project(ST_MakePoint(longitude,latitude)::geography, $distance+steps*10, radians((azimuth+30)%360))),
        ST_AsText(ST_MakePoint(longitude,latitude))
        ]))
        FROM
        sector_location_csv
        left join(
        SELECT   ROW_NUMBER() OVER (ORDER BY uarfcndl NULLS LAST) AS steps, *
        FROM     (SELECT DISTINCT uarfcndl FROM SECTOR_LOCATION_CSV) A
        ORDER BY uarfcndl
        ) m
        on
        m.uarfcndl=sector_location_csv.uarfcndl
        ORDER BY sector_location_csv.uarfcndl desc
        ;' ||i into query;
        EXECUTE replace(query,'$distance',cast (d as text));
        d=d+step;

--RETURN 1;
END;
$dbvis$ LANGUAGE plpgsql
/

SELECT * from create_uarfcndl_polygons_layers_single('uarfcndl_all',40,30);
