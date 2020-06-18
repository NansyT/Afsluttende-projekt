--
-- PostgreSQL database dump
--

-- Dumped from database version 12.2
-- Dumped by pg_dump version 12.2

-- Started on 2020-06-17 12:06:48

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

DROP DATABASE landlyst;
--
-- TOC entry 2900 (class 1262 OID 16393)
-- Name: landlyst; Type: DATABASE; Schema: -; Owner: postgres
--

CREATE DATABASE landlyst WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'Danish_Denmark.1252' LC_CTYPE = 'Danish_Denmark.1252';


ALTER DATABASE landlyst OWNER TO postgres;

\connect landlyst

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 2 (class 3079 OID 16459)
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- TOC entry 2901 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- TOC entry 236 (class 1255 OID 24608)
-- Name: fc_calculatetotalprice(date, date, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fc_calculatetotalprice(datein date, dateout date, roomid integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE -- der bliver declaret 2 værdier som vi har brug for til udregningen
	price NUMERIC(18,2);
	result NUMERIC(18,2);
BEGIN

-- Udregningen forgår sammentid med vi sætter price til værdien
	SELECT 
	--det første cast er til at konvertere hele resultatet til NUMERIC
	--Det næste cast er til at konvertere dato forskellen til en int for at kunne gange det med prisen
	INTO price CAST((room.price + SUM(additional_services.price)) * CAST((dateout::date) - (datein::date) AS INT) AS NUMERIC(18,2))
	FROM room
	--alle joines er til at få priserne på tillægsydelserne 
	JOIN public.roomservices
	ON roomservices.pk_fk_room_id = room.pk_room_id
	JOIN public.additional_services
	ON additional_services.pk_supplement_id = roomservices.pk_fk_supplement_id
	WHERE room.pk_room_id = roomid
	--Der er nød til at blive grupperet da vi laver en SUM
	GROUP BY room.price;
	--Hvis perioden for bookingen er 7 dage eller mere er der 10% på  
	CASE
		WHEN CAST((dateout::date) - (datein::date) AS INT) >= 7 THEN 
			--udregner prisen med procent
			result = CAST(price -( ( (price)/100)*10) AS NUMERIC(18,2));
		ELSE 
			result = price;
			  END CASE ;
	RETURN result;
	 END; $$;


ALTER FUNCTION public.fc_calculatetotalprice(datein date, dateout date, roomid integer) OWNER TO postgres;

--
-- TOC entry 235 (class 1255 OID 24678)
-- Name: fc_checkifroomisavailable(character varying, character varying, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fc_checkifroomisavailable(datein character varying, dateout character varying, roomid integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE 
	result INTEGER;
BEGIN
	 SELECT INTO result CAST(COUNT(1) AS INT) 
	 FROM booking
	 WHERE fk_room_id = roomid
	 	AND ( (CAST(datein as date) > chek_in_date and CAST(datein as date) < check_out_date)
	 		OR ( CAST(dateout as date) > chek_in_date and CAST(dateout as date) <check_out_date));
	RETURN result;
END; $$;


ALTER FUNCTION public.fc_checkifroomisavailable(datein character varying, dateout character varying, roomid integer) OWNER TO postgres;

--
-- TOC entry 237 (class 1255 OID 24677)
-- Name: fc_getavailableroom(character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fc_getavailableroom(datein character varying, dateout character varying, par1 character varying, par2 character varying, par3 character varying, par4 character varying, par5 character varying, par6 character varying, par7 character varying) RETURNS TABLE(roomid integer, services character varying, priceday numeric, totalprice numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
	RETURN QUERY
	SELECT RoomFunc.RoomID AS roomid, 
		CAST(string_agg(description::VARCHAR, ', ') AS VARCHAR) AS Service,
		CAST(room.price + SUM(additional_services.price) as NUMERIC(18,2)) AS pricepday,
		CAST(totalpricetable AS NUMERIC(18,2))  AS totalprice
	FROM FC_getroomid(datein, dateout, par1, par2, par3, par4, par5, par6, par7) AS RoomFunc
	LEFT JOIN room
	ON room.pk_room_id = RoomFunc.RoomID
	LEFT JOIN public.roomservices
	ON roomservices.pk_fk_room_id = room.pk_room_id
	LEFT JOIN public.additional_services
	ON additional_services.pk_supplement_id = roomservices.pk_fk_supplement_id
	CROSS JOIN FC_CalculateTotalPrice(CAST(datein as date), CAST(dateout as date), RoomFunc.RoomID) AS totalpricetable
	GROUP BY RoomFunc.RoomID, room.price, totalpricetable.totalpricetable ;
END; $$;


ALTER FUNCTION public.fc_getavailableroom(datein character varying, dateout character varying, par1 character varying, par2 character varying, par3 character varying, par4 character varying, par5 character varying, par6 character varying, par7 character varying) OWNER TO postgres;

--
-- TOC entry 240 (class 1255 OID 24676)
-- Name: fc_getroomid(character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fc_getroomid(datein character varying, dateout character varying, par1 character varying, par2 character varying, par3 character varying, par4 character varying, par5 character varying, par6 character varying, par7 character varying) RETURNS TABLE(roomid integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
RETURN QUERY SELECT CAST(room.pk_room_id as INTEGER)
	FROM room
	LEFT JOIN public.booking
		ON fk_room_id = pk_room_id
	LEFT JOIN public.roomservices
		ON roomservices.pk_fk_room_id = room.pk_room_id
	LEFT JOIN public.additional_services
		ON additional_services.pk_supplement_id = roomservices.pk_fk_supplement_id
	LEFT JOIN fp_getServiceasString() AS serviceFunc
		ON serviceFunc.pk_room_id = room.pk_room_id
	WHERE COALESCE(booking.check_out_date, '9999-12-31') >= CAST(dateout as date)
		AND COALESCE(booking.chek_in_date, '1900-01-01') <= CAST(datein as date)
		AND (serviceFunc.servicestr LIKE ('%' || par1 || '%')
		AND serviceFunc.servicestr LIKE ('%' || par2 || '%')
		AND serviceFunc.servicestr LIKE ('%' || par3 || '%')
		AND serviceFunc.servicestr LIKE ('%' || par4 || '%')
		AND serviceFunc.servicestr LIKE ('%' || par5 || '%')
		AND serviceFunc.servicestr LIKE ('%' || par6 || '%')
		AND serviceFunc.servicestr LIKE ('%' || par7 || '%'))
		GROUP BY room.pk_room_id
;
	
END; $$;


ALTER FUNCTION public.fc_getroomid(datein character varying, dateout character varying, par1 character varying, par2 character varying, par3 character varying, par4 character varying, par5 character varying, par6 character varying, par7 character varying) OWNER TO postgres;

--
-- TOC entry 241 (class 1255 OID 24704)
-- Name: fp_get_alluserdata_roomdata(date, date, character varying, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fp_get_alluserdata_roomdata(checkin date, checkout date, customermail character varying, roomidinput integer) RETURNS TABLE(roomid integer, services character varying, email character varying, fullname character varying, address character varying, zipcode integer, phone integer, city character varying, pricepday numeric, indate date, outdate date, totalnights integer, totalprice numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
	RETURN QUERY 
	SELECT roomidinput,
		roomdata.servicestr,
		customer.pk_email, 
		customer.fullname,
		customer.address,
		customer.zip_code,
		customer.phone_nr,
		citycode.city,
		roomdata.pricepday,
		checkin,
		checkout,
		roomdata.totalnights,
		roomdata.totalprice
	FROM customer
	LEFT JOIN citycode
		ON citycode.pk_zip_code = customer.zip_code
	LEFT JOIN fp_get_roomdata(roomidinput, checkin, checkout) AS roomdata
		ON roomdata.roomid = roomidinput
	WHERE customer.pk_email = customermail;
END; $$;


ALTER FUNCTION public.fp_get_alluserdata_roomdata(checkin date, checkout date, customermail character varying, roomidinput integer) OWNER TO postgres;

--
-- TOC entry 242 (class 1255 OID 24706)
-- Name: fp_get_roomdata(integer, date, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fp_get_roomdata(roomidinput integer, datein date, dateout date) RETURNS TABLE(roomid integer, servicestr character varying, pricepday numeric, totalnights integer, totalprice numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
	RETURN QUERY SELECT servicestr.pk_room_id,
		servicestr.servicestr,
		CAST(room.price + SUM(additional_services.price) as NUMERIC(18,2)) AS pricepday,
		CAST((dateout::date) - (datein::date) AS int) AS totalnights,
		CAST(totalpricetable AS NUMERIC(18,2))  AS totalprice
	FROM room
	JOIN public.fp_getserviceasstring() AS servicestr
		ON servicestr.pk_room_id = roomidinput
	JOIN public.roomservices
		ON roomservices.pk_fk_room_id = room.pk_room_id
	JOIN public.additional_services
		ON additional_services.pk_supplement_id = roomservices.pk_fk_supplement_id
	CROSS JOIN FC_CalculateTotalPrice(CAST(datein as date), CAST(dateout as date), roomidinput) AS totalpricetable
	WHERE room.pk_room_id = roomidinput
	GROUP BY room.price, servicestr.pk_room_id, servicestr.servicestr, totalnights, totalprice;
END; $$;


ALTER FUNCTION public.fp_get_roomdata(roomidinput integer, datein date, dateout date) OWNER TO postgres;

--
-- TOC entry 238 (class 1255 OID 24693)
-- Name: fp_getserviceasstring(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fp_getserviceasstring() RETURNS TABLE(servicestr character varying, pk_room_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
	RETURN QUERY SELECT
		CAST(string_agg(description::VARCHAR, ', ') AS VARCHAR) AS Serviceroom,
		room.pk_room_id AS roomid
	FROM room
	LEFT JOIN public.roomservices
	ON roomservices.pk_fk_room_id = room.pk_room_id
	LEFT JOIN public.additional_services
	ON additional_services.pk_supplement_id = roomservices.pk_fk_supplement_id
	GROUP BY room.pk_room_id, room.price ;
END; $$;


ALTER FUNCTION public.fp_getserviceasstring() OWNER TO postgres;

--
-- TOC entry 234 (class 1255 OID 24612)
-- Name: pr_createreservation(integer, character varying, date, date); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.pr_createreservation(roomid integer, customermail character varying, datein date, dateout date)
    LANGUAGE plpgsql
    AS $$
DECLARE 
	room INT;
BEGIN
	SELECT * 
		INTO room
	FROM FC_CheckIfRoomIsAvailable(datein, dateout, roomID);
    IF (room > 0 )
		THEN RAISE NOTICE 'No rooms';
	ELSE 
		INSERT INTO booking(fk_room_id, fk_customer_email, chek_in_date, check_out_date) VALUES(roomID, customermail, datein, dateout);
		END IF;
    COMMIT;
END;
$$;


ALTER PROCEDURE public.pr_createreservation(roomid integer, customermail character varying, datein date, dateout date) OWNER TO postgres;

--
-- TOC entry 239 (class 1255 OID 24707)
-- Name: testpis(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.testpis(par character varying) RETURNS TABLE(fullname character varying, address character varying, zipcode integer, phone integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
	RETURN QUERY SELECT customer.fullname, customer.address, customer.zip_code, customer.phone_nr FROM customer WHERE pk_email = par ;
END; $$;


ALTER FUNCTION public.testpis(par character varying) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 207 (class 1259 OID 16802)
-- Name: additional_services; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.additional_services (
    pk_supplement_id integer NOT NULL,
    description character varying,
    price numeric(18,2)
);


ALTER TABLE public.additional_services OWNER TO postgres;

--
-- TOC entry 206 (class 1259 OID 16773)
-- Name: booking; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.booking (
    pk_reservation_id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    fk_room_id integer,
    fk_customer_email character varying,
    chek_in_date date NOT NULL,
    check_out_date date NOT NULL
);


ALTER TABLE public.booking OWNER TO postgres;

--
-- TOC entry 203 (class 1259 OID 16752)
-- Name: citycode; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.citycode (
    pk_zip_code integer NOT NULL,
    city character varying NOT NULL
);


ALTER TABLE public.citycode OWNER TO postgres;

--
-- TOC entry 204 (class 1259 OID 16760)
-- Name: customer; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.customer (
    pk_email character varying NOT NULL,
    fullname character varying NOT NULL,
    address character varying NOT NULL,
    zip_code integer NOT NULL,
    phone_nr integer NOT NULL,
    password character varying NOT NULL
);


ALTER TABLE public.customer OWNER TO postgres;

--
-- TOC entry 211 (class 1259 OID 24699)
-- Name: datetesttable; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.datetesttable (
    testdate date,
    testuuid uuid
);


ALTER TABLE public.datetesttable OWNER TO postgres;

--
-- TOC entry 205 (class 1259 OID 16768)
-- Name: room; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.room (
    pk_room_id integer NOT NULL,
    price numeric(18,2),
    "Status" integer
);


ALTER TABLE public.room OWNER TO postgres;

--
-- TOC entry 208 (class 1259 OID 16810)
-- Name: roomservices; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.roomservices (
    pk_fk_room_id integer NOT NULL,
    pk_fk_supplement_id integer NOT NULL
);


ALTER TABLE public.roomservices OWNER TO postgres;

--
-- TOC entry 209 (class 1259 OID 24669)
-- Name: test; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.test (
    test text
);


ALTER TABLE public.test OWNER TO postgres;

--
-- TOC entry 210 (class 1259 OID 24685)
-- Name: test123; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.test123 (
    serviceroom character varying
);


ALTER TABLE public.test123 OWNER TO postgres;

--
-- TOC entry 2890 (class 0 OID 16802)
-- Dependencies: 207
-- Data for Name: additional_services; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.additional_services (pk_supplement_id, description, price) VALUES (1, 'Altan', 150.00);
INSERT INTO public.additional_services (pk_supplement_id, description, price) VALUES (2, 'Dobbeltseng', 200.00);
INSERT INTO public.additional_services (pk_supplement_id, description, price) VALUES (3, '2 Enkeltsenge', 200.00);
INSERT INTO public.additional_services (pk_supplement_id, description, price) VALUES (4, 'Badekar', 50.00);
INSERT INTO public.additional_services (pk_supplement_id, description, price) VALUES (5, 'Jacuzzi', 175.00);
INSERT INTO public.additional_services (pk_supplement_id, description, price) VALUES (6, 'Eget køkken', 350.00);
INSERT INTO public.additional_services (pk_supplement_id, description, price) VALUES (7, 'Enkeltmands seng', 0.00);


--
-- TOC entry 2889 (class 0 OID 16773)
-- Dependencies: 206
-- Data for Name: booking; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.booking (pk_reservation_id, fk_room_id, fk_customer_email, chek_in_date, check_out_date) VALUES ('c077a75a-3e71-42cc-948e-dd2b6d208558', 100, 'test', '2020-06-11', '2020-06-18');
INSERT INTO public.booking (pk_reservation_id, fk_room_id, fk_customer_email, chek_in_date, check_out_date) VALUES ('99d95d45-aaf8-4cff-a911-2977132929e6', 100, 'test', '2020-06-06', '2020-06-10');


--
-- TOC entry 2886 (class 0 OID 16752)
-- Dependencies: 203
-- Data for Name: citycode; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.citycode (pk_zip_code, city) VALUES (555, 'Scanning');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (783, 'Facility');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (800, 'Høje Taastrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (877, 'København C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (892, 'Sjælland USF P');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (893, 'Sjælland USF B');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (894, 'Udbetaling');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (899, 'Kommuneservice');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (900, 'København C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (910, 'København C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (913, 'Københavns Pakkecenter');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (914, 'Københavns Pakkecenter');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (917, 'Københavns Pakkecenter');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (918, 'Københavns Pakke BRC');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (919, 'Returprint BRC');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (929, 'København C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (960, 'Internationalt Postcenter');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (999, 'København C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1001, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1002, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1003, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1004, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1005, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1006, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1007, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1008, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1009, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1010, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1011, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1012, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1013, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1014, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1015, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1016, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1017, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1018, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1019, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1020, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1021, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1022, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1023, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1024, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1025, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1026, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1045, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1050, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1051, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1052, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1053, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1054, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1055, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1056, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1057, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1058, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1059, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1060, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1061, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1062, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1063, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1064, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1065, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1066, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1067, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1068, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1069, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1070, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1071, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1072, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1073, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1074, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1092, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1093, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1095, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1098, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1100, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1101, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1102, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1103, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1104, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1105, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1106, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1107, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1110, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1111, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1112, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1113, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1114, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1115, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1116, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1117, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1118, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1119, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1120, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1121, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1122, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1123, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1124, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1125, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1126, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1127, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1128, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1129, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1130, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1131, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1140, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1147, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1148, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1150, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1151, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1152, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1153, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1154, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1155, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1156, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1157, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1158, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1159, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1160, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1161, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1162, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1164, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1165, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1166, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1167, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1168, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1169, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1170, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1171, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1172, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1173, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1174, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1175, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1200, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1201, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1202, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1203, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1204, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1205, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1206, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1207, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1208, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1209, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1210, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1211, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1212, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1213, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1214, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1215, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1216, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1217, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1218, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1219, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1220, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1221, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1240, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1250, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1251, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1252, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1253, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1254, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1255, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1256, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1257, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1260, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1261, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1263, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1264, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1265, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1266, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1267, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1268, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1270, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1271, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1300, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1301, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1302, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1303, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1304, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1306, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1307, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1308, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1309, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1310, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1311, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1312, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1313, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1314, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1315, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1316, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1317, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1318, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1319, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1320, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1321, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1322, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1323, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1324, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1325, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1326, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1327, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1328, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1329, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1350, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1352, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1353, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1354, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1355, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1356, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1357, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1358, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1359, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1360, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1361, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1362, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1363, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1364, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1365, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1366, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1367, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1368, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1369, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1370, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1371, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1400, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1401, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1402, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1403, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1406, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1407, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1408, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1409, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1410, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1411, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1412, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1413, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1414, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1415, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1416, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1417, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1418, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1419, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1420, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1421, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1422, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1423, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1424, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1425, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1426, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1427, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1428, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1429, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1430, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1432, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1433, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1434, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1435, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1436, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1437, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1438, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1439, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1440, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1441, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1448, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1450, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1451, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1452, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1453, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1454, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1455, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1456, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1457, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1458, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1459, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1460, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1461, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1462, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1463, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1464, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1465, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1466, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1467, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1468, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1470, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1471, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1472, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1473, 'København K');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1500, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1501, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1502, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1503, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1504, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1505, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1506, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1507, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1508, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1509, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1510, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1512, 'Returpost');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1513, 'Flytninger og Nejtak');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1532, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1533, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1550, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1551, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1552, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1553, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1554, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1555, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1556, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1557, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1558, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1559, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1560, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1561, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1562, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1563, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1564, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1567, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1568, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1569, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1570, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1571, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1572, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1573, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1574, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1575, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1576, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1577, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1592, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1599, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1600, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1601, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1602, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1603, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1604, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1605, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1606, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1607, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1608, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1609, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1610, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1611, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1612, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1613, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1614, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1615, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1616, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1617, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1618, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1619, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1620, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1621, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1622, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1623, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1624, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1630, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1631, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1632, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1633, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1634, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1635, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1650, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1651, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1652, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1653, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1654, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1655, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1656, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1657, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1658, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1659, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1660, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1661, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1662, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1663, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1664, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1665, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1666, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1667, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1668, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1669, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1670, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1671, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1672, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1673, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1674, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1675, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1676, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1677, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1699, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1700, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1701, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1702, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1703, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1704, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1705, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1706, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1707, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1708, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1709, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1710, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1711, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1712, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1714, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1715, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1716, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1717, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1718, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1719, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1720, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1721, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1722, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1723, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1724, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1725, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1726, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1727, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1728, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1729, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1730, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1731, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1732, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1733, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1734, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1735, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1736, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1737, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1738, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1739, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1749, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1750, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1751, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1752, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1753, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1754, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1755, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1756, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1757, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1758, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1759, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1760, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1761, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1762, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1763, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1764, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1765, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1766, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1770, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1771, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1772, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1773, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1774, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1775, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1777, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1780, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1782, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1785, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1786, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1787, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1790, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1799, 'København V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1800, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1801, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1802, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1803, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1804, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1805, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1806, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1807, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1808, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1809, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1810, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1811, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1812, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1813, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1814, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1815, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1816, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1817, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1818, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1819, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1820, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1822, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1823, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1824, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1825, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1826, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1827, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1828, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1829, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1835, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1850, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1851, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1852, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1853, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1854, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1855, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1856, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1857, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1860, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1861, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1862, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1863, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1864, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1865, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1866, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1867, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1868, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1870, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1871, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1872, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1873, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1874, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1875, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1876, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1877, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1878, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1879, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1900, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1901, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1902, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1903, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1904, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1905, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1906, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1908, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1909, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1910, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1911, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1912, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1913, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1914, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1915, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1916, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1917, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1920, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1921, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1922, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1923, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1924, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1925, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1926, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1927, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1928, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1931, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1950, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1951, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1952, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1953, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1954, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1955, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1956, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1957, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1958, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1959, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1960, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1961, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1962, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1963, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1964, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1965, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1966, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1967, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1970, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1971, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1972, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1973, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (1974, 'Frederiksberg C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2000, 'Frederiksberg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2100, 'København Ø');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2150, 'Nordhavn');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2200, 'København ');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2300, 'København S');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2400, 'København NV');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2412, 'Grønland');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2450, 'København SV');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2500, 'Valby');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2600, 'Glostrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2605, 'Brøndby');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2610, 'Rødovre');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2620, 'Albertslund');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2625, 'Vallensbæk');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2630, 'Taastrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2635, 'Ishøj');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2640, 'Hedehusene');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2650, 'Hvidovre');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2660, 'Brøndby Strand');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2665, 'Vallensbæk Strand');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2670, 'Greve');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2680, 'Solrød Strand');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2690, 'Karlslunde');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2700, 'Brønshøj');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2720, 'Vanløse');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2730, 'Herlev');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2740, 'Skovlunde');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2750, 'Ballerup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2760, 'Måløv');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2765, 'Smørum');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2770, 'Kastrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2791, 'Dragør');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2800, 'Kongens Lyngby');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2820, 'Gentofte');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2830, 'Virum');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2840, 'Holte');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2850, 'Nærum');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2860, 'Søborg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2870, 'Dyssegård');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2880, 'Bagsværd');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2900, 'Hellerup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2920, 'Charlottenlund');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2930, 'Klampenborg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2942, 'Skodsborg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2950, 'Vedbæk');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2960, 'Rungsted Kyst');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2970, 'Hørsholm');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2980, 'Kokkedal');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (2990, 'Nivå');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3000, 'Helsingør');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3050, 'Humlebæk');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3060, 'Espergærde');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3070, 'Snekkersten');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3080, 'Tikøb');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3100, 'Hornbæk');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3120, 'Dronningmølle');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3140, 'Ålsgårde');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3150, 'Hellebæk');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3200, 'Helsinge');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3210, 'Vejby');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3220, 'Tisvildeleje');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3230, 'Græsted');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3250, 'Gilleleje');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3300, 'Frederiksværk');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3310, 'Ølsted');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3320, 'Skævinge');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3330, 'Gørløse');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3360, 'Liseleje');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3370, 'Melby');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3390, 'Hundested');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3400, 'Hillerød');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3450, 'Allerød');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3460, 'Birkerød');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3480, 'Fredensborg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3490, 'Kvistgård');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3500, 'Værløse');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3520, 'Farum');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3540, 'Lynge');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3550, 'Slangerup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3600, 'Frederikssund');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3630, 'Jægerspris');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3650, 'Ølstykke');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3660, 'Stenløse');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3670, 'Veksø Sjælland');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3700, 'Rønne');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3720, 'Aakirkeby');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3730, 'Nexø');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3740, 'Svaneke');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3751, 'Østermarie');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3760, 'Gudhjem');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3770, 'Allinge');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3782, 'Klemensker');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (3790, 'Hasle');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4000, 'Roskilde');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4030, 'Tune');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4040, 'Jyllinge');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4050, 'Skibby');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4060, 'Kirke Såby');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4070, 'Kirke Hyllinge');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4100, 'Ringsted');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4129, 'Ringsted');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4130, 'Viby Sjælland');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4140, 'Borup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4160, 'Herlufmagle');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4171, 'Glumsø');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4173, 'Fjenneslev');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4174, 'Jystrup Midtsj');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4180, 'Sorø');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4190, 'Munke Bjergby');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4200, 'Slagelse');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4220, 'Korsør');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4230, 'Skælskør');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4241, 'Vemmelev');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4242, 'Boeslunde');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4243, 'Rude');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4244, 'Agersø');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4245, 'Omø');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4250, 'Fuglebjerg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4261, 'Dalmose');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4262, 'Sandved');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4270, 'Høng');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4281, 'Gørlev');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4291, 'Ruds Vedby');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4293, 'Dianalund');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4295, 'Stenlille');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4296, 'Nyrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4300, 'Holbæk');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4305, 'Orø');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4320, 'Lejre');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4330, 'Hvalsø');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4340, 'Tølløse');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4350, 'Ugerløse');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4360, 'Kirke Eskilstrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4370, 'Store Merløse');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4390, 'Vipperød');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4400, 'Kalundborg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4420, 'Regstrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4440, 'Mørkøv');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4450, 'Jyderup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4460, 'Snertinge');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4470, 'Svebølle');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4480, 'Store Fuglede');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4490, 'Jerslev Sjælland');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4500, 'Nykøbing Sj');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4520, 'Svinninge');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4532, 'Gislinge');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4534, 'Hørve');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4540, 'Fårevejle');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4550, 'Asnæs');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4560, 'Vig');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4571, 'Grevinge');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4572, 'Nørre Asmindrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4573, 'Højby');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4581, 'Rørvig');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4583, 'Sjællands Odde');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4591, 'Føllenslev');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4592, 'Sejerø');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4593, 'Eskebjerg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4600, 'Køge');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4621, 'Gadstrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4622, 'Havdrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4623, 'Lille Skensved');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4632, 'Bjæverskov');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4640, 'Faxe');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4652, 'Hårlev');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4653, 'Karise');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4654, 'Faxe Ladeplads');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4660, 'Store Heddinge');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4671, 'Strøby');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4672, 'Klippinge');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4673, 'Rødvig Stevns');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4681, 'Herfølge');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4682, 'Tureby');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4683, 'Rønnede');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4684, 'Holmegaard');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4690, 'Haslev');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4700, 'Næstved');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4720, 'Præstø');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4733, 'Tappernøje');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4735, 'Mern');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4736, 'Karrebæksminde');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4750, 'Lundby');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4760, 'Vordingborg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4771, 'Kalvehave');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4772, 'Langebæk');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4773, 'Stensved');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4780, 'Stege');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4791, 'Borre');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4792, 'Askeby');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4793, 'Bogø By');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4800, 'Nykøbing F');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4840, 'Nørre Alslev');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4850, 'Stubbekøbing');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4862, 'Guldborg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4863, 'Eskilstrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4871, 'Horbelev');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4872, 'Idestrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4873, 'Væggerløse');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4874, 'Gedser');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4880, 'Nysted');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4891, 'Toreby L');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4892, 'Kettinge');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4894, 'Øster Ulslev');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4895, 'Errindlev');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4900, 'Nakskov');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4912, 'Harpelunde');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4913, 'Horslunde');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4920, 'Søllested');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4930, 'Maribo');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4941, 'Bandholm');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4942, 'Askø og Lilleø');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4943, 'Torrig L');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4944, 'Fejø');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4945, 'Femø');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4951, 'Nørreballe');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4952, 'Stokkemarke');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4953, 'Vesterborg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4960, 'Holeby');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4970, 'Rødby');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4983, 'Dannemare');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4990, 'Sakskøbing');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (4992, 'Midtsjælland USF P');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5000, 'Odense C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5029, 'Odense C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5100, 'Odense C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5200, 'Odense V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5210, 'Odense NV');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5220, 'Odense SØ');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5230, 'Odense M');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5240, 'Odense NØ');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5250, 'Odense SV');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5260, 'Odense S');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5270, 'Odense ');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5290, 'Marslev');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5300, 'Kerteminde');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5320, 'Agedrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5330, 'Munkebo');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5350, 'Rynkeby');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5370, 'Mesinge');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5380, 'Dalby');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5390, 'Martofte');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5400, 'Bogense');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5450, 'Otterup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5462, 'Morud');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5463, 'Harndrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5464, 'Brenderup Fyn');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5466, 'Asperup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5471, 'Søndersø');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5474, 'Veflinge');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5485, 'Skamby');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5491, 'Blommenslyst');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5492, 'Vissenbjerg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5500, 'Middelfart');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5540, 'Ullerslev');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5550, 'Langeskov');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5560, 'Aarup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5580, 'Nørre Aaby');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5591, 'Gelsted');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5592, 'Ejby');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5600, 'Faaborg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5601, 'Lyø');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5602, 'Avernakø');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5603, 'Bjørnø');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5610, 'Assens');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5620, 'Glamsbjerg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5631, 'Ebberup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5642, 'Millinge');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5672, 'Broby');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5683, 'Haarby');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5690, 'Tommerup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5700, 'Svendborg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5750, 'Ringe');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5762, 'Vester Skerninge');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5771, 'Stenstrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5772, 'Kværndrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5792, 'Årslev');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5800, 'Nyborg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5853, 'Ørbæk');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5854, 'Gislev');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5856, 'Ryslinge');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5863, 'Ferritslev Fyn');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5871, 'Frørup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5874, 'Hesselager');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5881, 'Skårup Fyn');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5882, 'Vejstrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5883, 'Oure');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5884, 'Gudme');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5892, 'Gudbjerg Sydfyn');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5900, 'Rudkøbing');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5932, 'Humble');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5935, 'Bagenkop');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5943, 'Strynø');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5953, 'Tranekær');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5960, 'Marstal');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5965, 'Birkholm');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5970, 'Ærøskøbing');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (5985, 'Søby Ærø');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6000, 'Kolding');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6040, 'Egtved');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6051, 'Almind');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6052, 'Viuf');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6064, 'Jordrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6070, 'Christiansfeld');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6091, 'Bjert');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6092, 'Sønder Stenderup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6093, 'Sjølund');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6094, 'Hejls');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6100, 'Haderslev');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6200, 'Aabenraa');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6210, 'Barsø');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6230, 'Rødekro');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6240, 'Løgumkloster');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6261, 'Bredebro');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6270, 'Tønder');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6280, 'Højer');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6300, 'Gråsten');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6310, 'Broager');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6320, 'Egernsund');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6330, 'Padborg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6340, 'Kruså');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6360, 'Tinglev');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6372, 'Bylderup-Bov');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6392, 'Bolderslev');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6400, 'Sønderborg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6430, 'Nordborg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6440, 'Augustenborg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6470, 'Sydals');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6500, 'Vojens');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6510, 'Gram');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6520, 'Toftlund');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6534, 'Agerskov');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6535, 'Branderup J');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6541, 'Bevtoft');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6560, 'Sommersted');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6580, 'Vamdrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6600, 'Vejen');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6621, 'Gesten');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6622, 'Bække');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6623, 'Vorbasse');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6630, 'Rødding');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6640, 'Lunderskov');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6650, 'Brørup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6660, 'Lintrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6670, 'Holsted');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6682, 'Hovborg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6683, 'Føvling');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6690, 'Gørding');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6700, 'Esbjerg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6701, 'Esbjerg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6705, 'Esbjerg Ø');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6710, 'Esbjerg V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6715, 'Esbjerg ');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6720, 'Fanø');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6731, 'Tjæreborg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6740, 'Bramming');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6752, 'Glejbjerg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6753, 'Agerbæk');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6760, 'Ribe');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6771, 'Gredstedbro');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6780, 'Skærbæk');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6792, 'Rømø');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6800, 'Varde');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6818, 'Årre');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6823, 'Ansager');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6830, 'Nørre Nebel');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6840, 'Oksbøl');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6851, 'Janderup Vestj');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6852, 'Billum');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6853, 'Vejers Strand');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6854, 'Henne');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6855, 'Outrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6857, 'Blåvand');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6862, 'Tistrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6870, 'Ølgod');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6880, 'Tarm');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6893, 'Hemmet');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6900, 'Skjern');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6920, 'Videbæk');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6933, 'Kibæk');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6940, 'Lem St');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6950, 'Ringkøbing');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6960, 'Hvide Sande');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6971, 'Spjald');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6973, 'Ørnhøj');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6980, 'Tim');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (6990, 'Ulfborg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7000, 'Fredericia');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7007, 'Fredericia');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7017, 'Taulov Pakkecenter');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7018, 'Pakker TLP');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7029, 'Fredericia');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7080, 'Børkop');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7100, 'Vejle');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7120, 'Vejle Øst');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7130, 'Juelsminde');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7140, 'Stouby');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7150, 'Barrit');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7160, 'Tørring');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7171, 'Uldum');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7173, 'Vonge');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7182, 'Bredsten');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7183, 'Randbøl');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7184, 'Vandel');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7190, 'Billund');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7200, 'Grindsted');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7250, 'Hejnsvig');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7260, 'Sønder Omme');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7270, 'Stakroge');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7280, 'Sønder Felding');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7300, 'Jelling');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7321, 'Gadbjerg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7323, 'Give');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7330, 'Brande');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7361, 'Ejstrupholm');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7362, 'Hampen');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7400, 'Herning');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7429, 'Herning');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7430, 'Ikast');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7441, 'Bording');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7442, 'Engesvang');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7451, 'Sunds');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7470, 'Karup J');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7480, 'Vildbjerg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7490, 'Aulum');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7500, 'Holstebro');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7540, 'Haderup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7550, 'Sørvad');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7560, 'Hjerm');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7570, 'Vemb');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7600, 'Struer');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7620, 'Lemvig');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7650, 'Bøvlingbjerg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7660, 'Bækmarksbro');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7673, 'Harboøre');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7680, 'Thyborøn');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7700, 'Thisted');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7730, 'Hanstholm');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7741, 'Frøstrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7742, 'Vesløs');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7752, 'Snedsted');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7755, 'Bedsted Thy');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7760, 'Hurup Thy');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7770, 'Vestervig');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7790, 'Thyholm');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7800, 'Skive');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7830, 'Vinderup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7840, 'Højslev');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7850, 'Stoholm Jyll');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7860, 'Spøttrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7870, 'Roslev');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7884, 'Fur');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7900, 'Nykøbing M');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7950, 'Erslev');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7960, 'Karby');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7970, 'Redsted M');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7980, 'Vils');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7990, 'Øster Assels');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7992, 'Sydjylland/Fyn USF P');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7993, 'Sydjylland/Fyn USF B');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7996, 'Fakturaservice');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7997, 'Fakturascanning');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7998, 'Statsservice');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (7999, 'Kommunepost');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8000, 'Aarhus C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8100, 'Aarhus C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8200, 'Aarhus ');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8210, 'Aarhus V');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8220, 'Brabrand');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8229, 'Risskov Ø');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8230, 'Åbyhøj');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8240, 'Risskov');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8245, 'Risskov Ø');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8250, 'Egå');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8260, 'Viby J');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8270, 'Højbjerg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8300, 'Odder');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8305, 'Samsø');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8310, 'Tranbjerg J');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8320, 'Mårslet');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8330, 'Beder');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8340, 'Malling');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8350, 'Hundslund');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8355, 'Solbjerg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8361, 'Hasselager');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8362, 'Hørning');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8370, 'Hadsten');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8380, 'Trige');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8381, 'Tilst');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8382, 'Hinnerup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8400, 'Ebeltoft');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8410, 'Rønde');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8420, 'Knebel');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8444, 'Balle');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8450, 'Hammel');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8462, 'Harlev J');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8464, 'Galten');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8471, 'Sabro');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8472, 'Sporup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8500, 'Grenaa');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8520, 'Lystrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8530, 'Hjortshøj');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8541, 'Skødstrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8543, 'Hornslet');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8544, 'Mørke');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8550, 'Ryomgård');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8560, 'Kolind');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8570, 'Trustrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8581, 'Nimtofte');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8585, 'Glesborg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8586, 'Ørum Djurs');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8592, 'Anholt');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8600, 'Silkeborg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8620, 'Kjellerup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8632, 'Lemming');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8641, 'Sorring');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8643, 'Ans By');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8653, 'Them');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8654, 'Bryrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8660, 'Skanderborg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8670, 'Låsby');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8680, 'Ry');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8700, 'Horsens');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8721, 'Daugård');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8722, 'Hedensted');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8723, 'Løsning');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8732, 'Hovedgård');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8740, 'Brædstrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8751, 'Gedved');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8752, 'Østbirk');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8762, 'Flemming');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8763, 'Rask Mølle');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8765, 'Klovborg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8766, 'Nørre Snede');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8781, 'Stenderup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8783, 'Hornsyld');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8789, 'Endelave');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8799, 'Tunø');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8800, 'Viborg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8830, 'Tjele');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8831, 'Løgstrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8832, 'Skals');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8840, 'Rødkærsbro');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8850, 'Bjerringbro');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8860, 'Ulstrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8870, 'Langå');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8881, 'Thorsø');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8882, 'Fårvang');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8883, 'Gjern');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8900, 'Randers C');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8920, 'Randers NV');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8930, 'Randers NØ');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8940, 'Randers SV');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8950, 'Ørsted');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8960, 'Randers SØ');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8961, 'Allingåbro');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8963, 'Auning');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8970, 'Havndal');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8981, 'Spentrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8983, 'Gjerlev J');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (8990, 'Fårup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9000, 'Aalborg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9029, 'Aalborg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9100, 'Aalborg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9200, 'Aalborg SV');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9210, 'Aalborg SØ');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9220, 'Aalborg Øst');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9230, 'Svenstrup J');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9240, 'Nibe');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9260, 'Gistrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9270, 'Klarup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9280, 'Storvorde');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9293, 'Kongerslev');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9300, 'Sæby');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9310, 'Vodskov');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9320, 'Hjallerup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9330, 'Dronninglund');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9340, 'Asaa');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9352, 'Dybvad');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9362, 'Gandrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9370, 'Hals');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9380, 'Vestbjerg');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9381, 'Sulsted');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9382, 'Tylstrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9400, 'Nørresundby');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9430, 'Vadum');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9440, 'Aabybro');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9460, 'Brovst');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9480, 'Løkken');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9490, 'Pandrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9492, 'Blokhus');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9493, 'Saltum');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9500, 'Hobro');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9510, 'Arden');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9520, 'Skørping');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9530, 'Støvring');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9541, 'Suldrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9550, 'Mariager');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9560, 'Hadsund');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9574, 'Bælum');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9575, 'Terndrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9600, 'Aars');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9610, 'Nørager');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9620, 'Aalestrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9631, 'Gedsted');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9632, 'Møldrup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9640, 'Farsø');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9670, 'Løgstør');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9681, 'Ranum');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9690, 'Fjerritslev');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9700, 'Brønderslev');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9740, 'Jerslev J');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9750, 'Østervrå');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9760, 'Vrå');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9800, 'Hjørring');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9830, 'Tårs');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9850, 'Hirtshals');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9870, 'Sindal');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9881, 'Bindslev');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9900, 'Frederikshavn');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9940, 'Læsø');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9970, 'Strandby');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9981, 'Jerup');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9982, 'Ålbæk');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9990, 'Skagen');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9992, 'Jylland USF P');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9993, 'Jylland USF B');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9996, 'Fakturaservice');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9997, 'Fakturascanning');
INSERT INTO public.citycode (pk_zip_code, city) VALUES (9998, 'Borgerservice');


--
-- TOC entry 2887 (class 0 OID 16760)
-- Dependencies: 204
-- Data for Name: customer; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.customer (pk_email, fullname, address, zip_code, phone_nr, password) VALUES ('test', 'test', 'test', 1234, 88888888, 'testtest');
INSERT INTO public.customer (pk_email, fullname, address, zip_code, phone_nr, password) VALUES ('test3', 'test', 'test', 1234, 88888888, 'testtest');
INSERT INTO public.customer (pk_email, fullname, address, zip_code, phone_nr, password) VALUES ('test8', 'test', 'test', 1234, 88888888, 'testtest');


--
-- TOC entry 2894 (class 0 OID 24699)
-- Dependencies: 211
-- Data for Name: datetesttable; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.datetesttable (testdate, testuuid) VALUES ('2020-06-16', 'b6b48c10-f9f1-474c-8987-e4d24d76b620');


--
-- TOC entry 2888 (class 0 OID 16768)
-- Dependencies: 205
-- Data for Name: room; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.room (pk_room_id, price, "Status") VALUES (100, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (101, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (102, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (103, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (104, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (105, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (106, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (107, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (108, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (109, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (110, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (200, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (201, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (202, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (203, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (204, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (205, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (206, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (207, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (208, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (209, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (300, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (301, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (302, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (303, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (304, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (305, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (306, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (307, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (308, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (309, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (400, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (401, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (402, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (403, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (404, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (405, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (406, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (407, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (408, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (409, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (500, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (501, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (502, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (503, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (504, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (506, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (507, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (508, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (509, 695.00, 1);
INSERT INTO public.room (pk_room_id, price, "Status") VALUES (510, 695.00, 1);


--
-- TOC entry 2891 (class 0 OID 16810)
-- Dependencies: 208
-- Data for Name: roomservices; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (301, 3);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (304, 3);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (501, 3);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (504, 7);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (408, 7);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (401, 7);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (407, 7);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (406, 7);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (404, 7);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (100, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (100, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (101, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (102, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (102, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (103, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (103, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (104, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (104, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (105, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (105, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (106, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (106, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (107, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (107, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (108, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (108, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (109, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (110, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (110, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (200, 1);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (200, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (200, 5);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (201, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (201, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (202, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (202, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (203, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (203, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (204, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (204, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (205, 1);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (205, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (205, 5);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (205, 6);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (206, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (206, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (207, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (207, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (208, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (208, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (209, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (209, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (209, 5);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (300, 1);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (300, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (300, 5);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (301, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (302, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (302, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (303, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (303, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (304, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (305, 1);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (305, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (305, 5);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (305, 6);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (306, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (306, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (307, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (307, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (308, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (308, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (309, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (309, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (309, 5);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (400, 1);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (400, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (400, 5);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (401, 1);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (401, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (402, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (402, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (403, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (403, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (404, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (405, 1);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (405, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (405, 5);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (405, 6);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (406, 1);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (407, 1);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (409, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (409, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (409, 5);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (500, 1);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (500, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (500, 5);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (501, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (502, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (502, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (503, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (503, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (504, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (506, 1);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (506, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (506, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (507, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (507, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (508, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (508, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (509, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (509, 4);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (510, 2);
INSERT INTO public.roomservices (pk_fk_room_id, pk_fk_supplement_id) VALUES (510, 4);


--
-- TOC entry 2892 (class 0 OID 24669)
-- Dependencies: 209
-- Data for Name: test; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.test (test) VALUES ('');
INSERT INTO public.test (test) VALUES ('test1');
INSERT INTO public.test (test) VALUES ('test1');


--
-- TOC entry 2893 (class 0 OID 24685)
-- Dependencies: 210
-- Data for Name: test123; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.test123 (serviceroom) VALUES ('Altan, Dobbeltseng, Jacuzzi');
INSERT INTO public.test123 (serviceroom) VALUES ('Dobbeltseng, Badekar');
INSERT INTO public.test123 (serviceroom) VALUES ('Altan, Dobbeltseng, Jacuzzi');
INSERT INTO public.test123 (serviceroom) VALUES ('Dobbeltseng, Badekar');
INSERT INTO public.test123 (serviceroom) VALUES ('Dobbeltseng, Badekar');
INSERT INTO public.test123 (serviceroom) VALUES ('Altan, Badekar');
INSERT INTO public.test123 (serviceroom) VALUES ('Dobbeltseng, Badekar, Jacuzzi');
INSERT INTO public.test123 (serviceroom) VALUES ('Altan, Dobbeltseng, Jacuzzi, Eget køkken');
INSERT INTO public.test123 (serviceroom) VALUES ('Dobbeltseng, Badekar');
INSERT INTO public.test123 (serviceroom) VALUES ('Dobbeltseng, Badekar');
INSERT INTO public.test123 (serviceroom) VALUES ('Altan, Dobbeltseng, Jacuzzi, Eget køkken');
INSERT INTO public.test123 (serviceroom) VALUES ('2 Enkeltsenge, Badekar');
INSERT INTO public.test123 (serviceroom) VALUES ('Dobbeltseng, Badekar');
INSERT INTO public.test123 (serviceroom) VALUES ('Altan');
INSERT INTO public.test123 (serviceroom) VALUES ('Dobbeltseng, Badekar');
INSERT INTO public.test123 (serviceroom) VALUES ('Dobbeltseng, Badekar');
INSERT INTO public.test123 (serviceroom) VALUES ('Dobbeltseng, Badekar');
INSERT INTO public.test123 (serviceroom) VALUES ('2 Enkeltsenge, Badekar');
INSERT INTO public.test123 (serviceroom) VALUES ('Dobbeltseng, Badekar');
INSERT INTO public.test123 (serviceroom) VALUES ('Dobbeltseng, Badekar');
INSERT INTO public.test123 (serviceroom) VALUES ('Dobbeltseng, Badekar');
INSERT INTO public.test123 (serviceroom) VALUES ('Dobbeltseng, Badekar');
INSERT INTO public.test123 (serviceroom) VALUES ('Altan');
INSERT INTO public.test123 (serviceroom) VALUES ('Dobbeltseng, Badekar');
INSERT INTO public.test123 (serviceroom) VALUES ('Altan, Dobbeltseng, Jacuzzi, Eget køkken');
INSERT INTO public.test123 (serviceroom) VALUES ('Dobbeltseng, Badekar');
INSERT INTO public.test123 (serviceroom) VALUES ('Dobbeltseng, Badekar');
INSERT INTO public.test123 (serviceroom) VALUES ('Dobbeltseng, Badekar');
INSERT INTO public.test123 (serviceroom) VALUES ('Altan, Dobbeltseng, Jacuzzi');
INSERT INTO public.test123 (serviceroom) VALUES ('Dobbeltseng, Badekar, Jacuzzi');
INSERT INTO public.test123 (serviceroom) VALUES ('Dobbeltseng');
INSERT INTO public.test123 (serviceroom) VALUES ('Dobbeltseng, Badekar');
INSERT INTO public.test123 (serviceroom) VALUES ('Dobbeltseng, Badekar, Jacuzzi');
INSERT INTO public.test123 (serviceroom) VALUES ('Dobbeltseng, Badekar');
INSERT INTO public.test123 (serviceroom) VALUES ('Badekar');
INSERT INTO public.test123 (serviceroom) VALUES ('Dobbeltseng, Badekar');
INSERT INTO public.test123 (serviceroom) VALUES ('Altan, Dobbeltseng, Badekar');
INSERT INTO public.test123 (serviceroom) VALUES ('Dobbeltseng, Badekar');
INSERT INTO public.test123 (serviceroom) VALUES ('Dobbeltseng, Badekar');
INSERT INTO public.test123 (serviceroom) VALUES ('2 Enkeltsenge, Badekar');
INSERT INTO public.test123 (serviceroom) VALUES ('Dobbeltseng');
INSERT INTO public.test123 (serviceroom) VALUES ('Dobbeltseng, Badekar');
INSERT INTO public.test123 (serviceroom) VALUES (NULL);
INSERT INTO public.test123 (serviceroom) VALUES ('Altan, Dobbeltseng, Jacuzzi');
INSERT INTO public.test123 (serviceroom) VALUES ('Badekar');
INSERT INTO public.test123 (serviceroom) VALUES ('Dobbeltseng, Badekar');
INSERT INTO public.test123 (serviceroom) VALUES ('Dobbeltseng, Badekar');
INSERT INTO public.test123 (serviceroom) VALUES ('Dobbeltseng, Badekar');
INSERT INTO public.test123 (serviceroom) VALUES ('Dobbeltseng, Badekar');
INSERT INTO public.test123 (serviceroom) VALUES ('Dobbeltseng, Badekar');
INSERT INTO public.test123 (serviceroom) VALUES ('Dobbeltseng, Badekar');


--
-- TOC entry 2753 (class 2606 OID 16809)
-- Name: additional_services additional_services_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.additional_services
    ADD CONSTRAINT additional_services_pkey PRIMARY KEY (pk_supplement_id);


--
-- TOC entry 2751 (class 2606 OID 16781)
-- Name: booking booking_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.booking
    ADD CONSTRAINT booking_pkey PRIMARY KEY (pk_reservation_id);


--
-- TOC entry 2745 (class 2606 OID 16759)
-- Name: citycode citycode_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.citycode
    ADD CONSTRAINT citycode_pkey PRIMARY KEY (pk_zip_code);


--
-- TOC entry 2747 (class 2606 OID 16767)
-- Name: customer customer_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.customer
    ADD CONSTRAINT customer_pkey PRIMARY KEY (pk_email);


--
-- TOC entry 2749 (class 2606 OID 16772)
-- Name: room room_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.room
    ADD CONSTRAINT room_pkey PRIMARY KEY (pk_room_id);


--
-- TOC entry 2755 (class 2606 OID 16814)
-- Name: roomservices roomservices_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roomservices
    ADD CONSTRAINT roomservices_pkey PRIMARY KEY (pk_fk_room_id, pk_fk_supplement_id);


--
-- TOC entry 2757 (class 2606 OID 16787)
-- Name: booking booking_fk_customer_email_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.booking
    ADD CONSTRAINT booking_fk_customer_email_fkey FOREIGN KEY (fk_customer_email) REFERENCES public.customer(pk_email);


--
-- TOC entry 2756 (class 2606 OID 16782)
-- Name: booking booking_fk_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.booking
    ADD CONSTRAINT booking_fk_room_id_fkey FOREIGN KEY (fk_room_id) REFERENCES public.room(pk_room_id);


--
-- TOC entry 2758 (class 2606 OID 16815)
-- Name: roomservices roomservices_pk_fk_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roomservices
    ADD CONSTRAINT roomservices_pk_fk_room_id_fkey FOREIGN KEY (pk_fk_room_id) REFERENCES public.room(pk_room_id);


--
-- TOC entry 2759 (class 2606 OID 16820)
-- Name: roomservices roomservices_pk_fk_supplement_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roomservices
    ADD CONSTRAINT roomservices_pk_fk_supplement_id_fkey FOREIGN KEY (pk_fk_supplement_id) REFERENCES public.additional_services(pk_supplement_id);


-- Completed on 2020-06-17 12:06:49

--
-- PostgreSQL database dump complete
--

