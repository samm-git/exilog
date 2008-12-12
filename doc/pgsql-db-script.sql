--
-- PostgreSQL database dump
--

SET client_encoding = 'LATIN1';
SET check_function_bodies = false;

--
-- TOC entry 3 (OID 17145)
-- Name: exilog; Type: SCHEMA; Schema: -; Owner: 
--

CREATE SCHEMA exilog AUTHORIZATION exilog;


SET SESSION AUTHORIZATION 'exilog';

SET search_path = exilog, pg_catalog;

--
-- TOC entry 4 (OID 17181)
-- Name: deferrals; Type: TABLE; Schema: exilog; Owner: exilog
--

CREATE TABLE deferrals (
    server character varying(32) NOT NULL,
    message_id character(16) NOT NULL,
    "timestamp" bigint NOT NULL,
    rcpt character varying(200) NOT NULL,
    rcpt_intermediate character varying(200),
    rcpt_final character varying(200) NOT NULL,
    host_addr inet,
    host_dns character varying(255),
    tls_cipher character varying(128),
    router character varying(128),
    transport character varying(128),
    shadow_transport character varying(128),
    errmsg character varying(2048)
);


--
-- TOC entry 5 (OID 17194)
-- Name: errors; Type: TABLE; Schema: exilog; Owner: exilog
--

CREATE TABLE errors (
    server character varying(32) NOT NULL,
    message_id character(16) NOT NULL,
    "timestamp" bigint NOT NULL,
    rcpt character varying(200) NOT NULL,
    rcpt_intermediate character varying(200),
    rcpt_final character varying(200) NOT NULL,
    host_addr inet,
    host_dns character varying(255),
    tls_cipher character varying(128),
    router character varying(128),
    transport character varying(128),
    shadow_transport character varying(128),
    errmsg character varying(2048)
);


--
-- TOC entry 6 (OID 17207)
-- Name: deliveries; Type: TABLE; Schema: exilog; Owner: exilog
--

CREATE TABLE deliveries (
    server character varying(32) NOT NULL,
    message_id character(16) NOT NULL,
    "timestamp" bigint NOT NULL,
    rcpt character varying(200) NOT NULL,
    rcpt_intermediate character varying(200),
    rcpt_final character varying(200) NOT NULL,
    host_addr inet,
    host_dns character varying(255),
    tls_cipher character varying(128),
    router character varying(128),
    transport character varying(128),
    shadow_transport character varying(128)
);


--
-- TOC entry 7 (OID 17220)
-- Name: queue; Type: TABLE; Schema: exilog; Owner: exilog
--

CREATE TABLE queue (
    server character varying(32) NOT NULL,
    message_id character(16) NOT NULL,
    mailfrom character varying(255),
    "timestamp" bigint,
    num_dsn integer,
    frozen bigint,
    recipients_delivered bytea,
    recipients_pending bytea,
    spool_path character varying(64),
    subject character varying(255),
    msgid character varying(255),
    headers bytea,
    "action" character varying(64)
);


--
-- TOC entry 8 (OID 17249)
-- Name: unknown; Type: TABLE; Schema: exilog; Owner: exilog
--

CREATE TABLE "unknown" (
    server character varying(32) NOT NULL,
    message_id character(16) NOT NULL,
    "timestamp" bigint NOT NULL,
    line character varying(255) NOT NULL
);


--
-- TOC entry 9 (OID 695844)
-- Name: messages; Type: TABLE; Schema: exilog; Owner: exilog
--

CREATE TABLE messages (
    server character varying(32) NOT NULL,
    message_id character(16) NOT NULL,
    "timestamp" bigint,
    msgid character varying(255),
    completed bigint,
    mailfrom character varying(255),
    host_addr inet,
    host_rdns character varying(255),
    host_ident character varying(255),
    host_helo character varying(255),
    proto character varying(32),
    size bigint,
    tls_cipher character varying(128),
    "user" character varying(128),
    bounce_parent character(16)
);


--
-- TOC entry 10 (OID 695860)
-- Name: rejects; Type: TABLE; Schema: exilog; Owner: exilog
--

CREATE TABLE rejects (
    server character varying(32) NOT NULL,
    message_id character(16),
    "timestamp" bigint NOT NULL,
    host_addr inet,
    host_rdns character varying(255),
    host_ident character varying(255),
    host_helo character varying(255),
    mailfrom character varying(255),
    rcpt character varying(255),
    errmsg character varying(255) NOT NULL
);


--
-- TOC entry 16 (OID 17188)
-- Name: deferrals_server; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX deferrals_server ON deferrals USING btree (server);


--
-- TOC entry 12 (OID 17189)
-- Name: deferrals_message_id; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX deferrals_message_id ON deferrals USING btree (message_id);


--
-- TOC entry 18 (OID 17190)
-- Name: deferrals_timestamp; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX deferrals_timestamp ON deferrals USING btree ("timestamp");


--
-- TOC entry 14 (OID 17191)
-- Name: deferrals_rcpt; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX deferrals_rcpt ON deferrals USING btree (rcpt);


--
-- TOC entry 15 (OID 17192)
-- Name: deferrals_rcpt_final; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX deferrals_rcpt_final ON deferrals USING btree (rcpt_final);


--
-- TOC entry 11 (OID 17193)
-- Name: deferrals_host_addr; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX deferrals_host_addr ON deferrals USING btree (host_addr);


--
-- TOC entry 24 (OID 17199)
-- Name: errors_server; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX errors_server ON errors USING btree (server);


--
-- TOC entry 20 (OID 17200)
-- Name: errors_message_id; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX errors_message_id ON errors USING btree (message_id);


--
-- TOC entry 26 (OID 17201)
-- Name: errors_timestamp; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX errors_timestamp ON errors USING btree ("timestamp");


--
-- TOC entry 22 (OID 17202)
-- Name: errors_rcpt; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX errors_rcpt ON errors USING btree (rcpt);


--
-- TOC entry 23 (OID 17203)
-- Name: errors_rcpt_final; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX errors_rcpt_final ON errors USING btree (rcpt_final);


--
-- TOC entry 19 (OID 17204)
-- Name: errors_host_addr; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX errors_host_addr ON errors USING btree (host_addr);


--
-- TOC entry 32 (OID 17212)
-- Name: deliveries_server; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX deliveries_server ON deliveries USING btree (server);


--
-- TOC entry 28 (OID 17213)
-- Name: deliveries_message_id; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX deliveries_message_id ON deliveries USING btree (message_id);


--
-- TOC entry 34 (OID 17214)
-- Name: deliveries_timestamp; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX deliveries_timestamp ON deliveries USING btree ("timestamp");


--
-- TOC entry 30 (OID 17215)
-- Name: deliveries_rcpt; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX deliveries_rcpt ON deliveries USING btree (rcpt);


--
-- TOC entry 31 (OID 17216)
-- Name: deliveries_rcpt_final; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX deliveries_rcpt_final ON deliveries USING btree (rcpt_final);


--
-- TOC entry 27 (OID 17217)
-- Name: deliveries_host_addr; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX deliveries_host_addr ON deliveries USING btree (host_addr);


--
-- TOC entry 41 (OID 17241)
-- Name: queue_server; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX queue_server ON queue USING btree (server);


--
-- TOC entry 38 (OID 17242)
-- Name: queue_message_id; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX queue_message_id ON queue USING btree (message_id);


--
-- TOC entry 37 (OID 17243)
-- Name: queue_mailfrom; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX queue_mailfrom ON queue USING btree (mailfrom);


--
-- TOC entry 44 (OID 17244)
-- Name: queue_timestamp; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX queue_timestamp ON queue USING btree ("timestamp");


--
-- TOC entry 36 (OID 17245)
-- Name: queue_frozen; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX queue_frozen ON queue USING btree (frozen);


--
-- TOC entry 43 (OID 17246)
-- Name: queue_spool_path; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX queue_spool_path ON queue USING btree (spool_path);


--
-- TOC entry 39 (OID 17247)
-- Name: queue_msgid; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX queue_msgid ON queue USING btree (msgid);


--
-- TOC entry 35 (OID 17248)
-- Name: queue_action; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX queue_action ON queue USING btree ("action");


--
-- TOC entry 47 (OID 17253)
-- Name: unknown_server; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX unknown_server ON "unknown" USING btree (server);


--
-- TOC entry 45 (OID 17254)
-- Name: unknown_message_id; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX unknown_message_id ON "unknown" USING btree (message_id);


--
-- TOC entry 49 (OID 17255)
-- Name: unknown_timestamp; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX unknown_timestamp ON "unknown" USING btree ("timestamp");


--
-- TOC entry 17 (OID 237716)
-- Name: deferrals_server_message_id; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX deferrals_server_message_id ON deferrals USING btree (server, message_id);


--
-- TOC entry 33 (OID 237717)
-- Name: deliveries_server_message_id; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX deliveries_server_message_id ON deliveries USING btree (server, message_id);


--
-- TOC entry 25 (OID 237719)
-- Name: errors_server_message_id; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX errors_server_message_id ON errors USING btree (server, message_id);


--
-- TOC entry 42 (OID 237725)
-- Name: queue_server_message_id; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX queue_server_message_id ON queue USING btree (server, message_id);


--
-- TOC entry 48 (OID 237821)
-- Name: unknown_server_message_id; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX unknown_server_message_id ON "unknown" USING btree (server, message_id);


--
-- TOC entry 57 (OID 695849)
-- Name: server; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX server ON messages USING btree (server);


--
-- TOC entry 53 (OID 695850)
-- Name: message_id; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX message_id ON messages USING btree (message_id);


--
-- TOC entry 55 (OID 695851)
-- Name: msgid; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX msgid ON messages USING btree (msgid);


--
-- TOC entry 58 (OID 695852)
-- Name: timestamp; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX "timestamp" ON messages USING btree ("timestamp");


--
-- TOC entry 51 (OID 695853)
-- Name: host_addr; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX host_addr ON messages USING btree (host_addr);


--
-- TOC entry 50 (OID 695854)
-- Name: bounce_parent; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX bounce_parent ON messages USING btree (bounce_parent);


--
-- TOC entry 59 (OID 695855)
-- Name: user; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX "user" ON messages USING btree ("user");


--
-- TOC entry 52 (OID 695856)
-- Name: mailfrom; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX mailfrom ON messages USING btree (mailfrom);


--
-- TOC entry 54 (OID 695857)
-- Name: messages_server_message_id; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX messages_server_message_id ON messages USING btree (server, message_id);


--
-- TOC entry 64 (OID 695865)
-- Name: rejects_server; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX rejects_server ON rejects USING btree (server);


--
-- TOC entry 66 (OID 695866)
-- Name: rejects_timestamp; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX rejects_timestamp ON rejects USING btree ("timestamp");


--
-- TOC entry 60 (OID 695867)
-- Name: rejects_host_addr; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX rejects_host_addr ON rejects USING btree (host_addr);


--
-- TOC entry 61 (OID 695868)
-- Name: rejects_mailfrom; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX rejects_mailfrom ON rejects USING btree (mailfrom);


--
-- TOC entry 63 (OID 695869)
-- Name: rejects_rcpt; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX rejects_rcpt ON rejects USING btree (rcpt);


--
-- TOC entry 62 (OID 695870)
-- Name: rejects_message_id; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX rejects_message_id ON rejects USING btree (message_id);


--
-- TOC entry 65 (OID 695871)
-- Name: rejects_server_message_id; Type: INDEX; Schema: exilog; Owner: exilog
--

CREATE INDEX rejects_server_message_id ON rejects USING btree (server, message_id);


--
-- TOC entry 13 (OID 17186)
-- Name: deferrals_primary; Type: CONSTRAINT; Schema: exilog; Owner: exilog
--

ALTER TABLE ONLY deferrals
    ADD CONSTRAINT deferrals_primary PRIMARY KEY (server, message_id, "timestamp", rcpt, rcpt_final);


--
-- TOC entry 21 (OID 17205)
-- Name: errors_primary; Type: CONSTRAINT; Schema: exilog; Owner: exilog
--

ALTER TABLE ONLY errors
    ADD CONSTRAINT errors_primary PRIMARY KEY (server, message_id, "timestamp", rcpt, rcpt_final);


--
-- TOC entry 29 (OID 17218)
-- Name: deliveries_primary; Type: CONSTRAINT; Schema: exilog; Owner: exilog
--

ALTER TABLE ONLY deliveries
    ADD CONSTRAINT deliveries_primary PRIMARY KEY (server, message_id, "timestamp", rcpt, rcpt_final);


--
-- TOC entry 40 (OID 17239)
-- Name: queue_primary; Type: CONSTRAINT; Schema: exilog; Owner: exilog
--

ALTER TABLE ONLY queue
    ADD CONSTRAINT queue_primary PRIMARY KEY (server, message_id);


--
-- TOC entry 46 (OID 17251)
-- Name: unknown_primary; Type: CONSTRAINT; Schema: exilog; Owner: exilog
--

ALTER TABLE ONLY "unknown"
    ADD CONSTRAINT unknown_primary PRIMARY KEY (server, message_id, "timestamp", line);


--
-- TOC entry 56 (OID 695858)
-- Name: primary; Type: CONSTRAINT; Schema: exilog; Owner: exilog
--

ALTER TABLE ONLY messages
    ADD CONSTRAINT "primary" PRIMARY KEY (server, message_id);


--
-- TOC entry 67 (OID 695872)
-- Name: rejects_unique; Type: CONSTRAINT; Schema: exilog; Owner: exilog
--

ALTER TABLE ONLY rejects
    ADD CONSTRAINT rejects_unique UNIQUE (server, "timestamp", host_addr, errmsg);
    
