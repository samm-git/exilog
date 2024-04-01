--
-- PostgreSQL database dump
--

SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

--
-- Name: exilog; Type: SCHEMA; Schema: -; Owner: exilog
--

CREATE SCHEMA exilog;


ALTER SCHEMA exilog OWNER TO exilog;

SET search_path = exilog, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: deferrals; Type: TABLE; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE TABLE deferrals (
    server character varying(32) NOT NULL,
    message_id character(23) NOT NULL,
    "timestamp" bigint NOT NULL,
    rcpt character varying(200) NOT NULL,
    rcpt_intermediate character varying(200),
    rcpt_final character varying(200) NOT NULL,
    host_addr inet,
    host_dns character varying(255),
    tls_cipher character varying(128),
    router character varying(128),
    transport character varying(128),
    shadow_transport character varying(255),
    errmsg character varying(2048)
);


ALTER TABLE exilog.deferrals OWNER TO exilog;

--
-- Name: deliveries; Type: TABLE; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE TABLE deliveries (
    server character varying(32) NOT NULL,
    message_id character(23) NOT NULL,
    "timestamp" bigint NOT NULL,
    rcpt character varying(200) NOT NULL,
    rcpt_intermediate character varying(200),
    rcpt_final character varying(200) NOT NULL,
    host_addr inet,
    host_dns character varying(255),
    tls_cipher character varying(128),
    router character varying(128),
    transport character varying(128),
    shadow_transport character varying(255)
);


ALTER TABLE exilog.deliveries OWNER TO exilog;

--
-- Name: errors; Type: TABLE; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE TABLE errors (
    server character varying(32) NOT NULL,
    message_id character(23) NOT NULL,
    "timestamp" bigint NOT NULL,
    rcpt character varying(200) NOT NULL,
    rcpt_intermediate character varying(200),
    rcpt_final character varying(200) NOT NULL,
    host_addr inet,
    host_dns character varying(255),
    tls_cipher character varying(128),
    router character varying(128),
    transport character varying(128),
    shadow_transport character varying(255),
    errmsg character varying(2048)
);


ALTER TABLE exilog.errors OWNER TO exilog;

--
-- Name: heartbeats; Type: TABLE; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE TABLE heartbeats (
    server character varying(32) NOT NULL,
    "timestamp" bigint NOT NULL
);


ALTER TABLE exilog.heartbeats OWNER TO exilog;

--
-- Name: messages; Type: TABLE; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE TABLE messages (
    server character varying(32) NOT NULL,
    message_id character(23) NOT NULL,
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


ALTER TABLE exilog.messages OWNER TO exilog;

--
-- Name: queue; Type: TABLE; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE TABLE queue (
    server character varying(32) NOT NULL,
    message_id character(23) NOT NULL,
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
    action character varying(64)
);


ALTER TABLE exilog.queue OWNER TO exilog;

--
-- Name: rejects; Type: TABLE; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE TABLE rejects (
    server character varying(32) NOT NULL,
    message_id character(23),
    "timestamp" bigint NOT NULL,
    host_addr inet,
    host_rdns character varying(255),
    host_ident character varying(255),
    host_helo character varying(255),
    mailfrom character varying(255),
    rcpt character varying(255),
    errmsg character varying(255) NOT NULL
);


ALTER TABLE exilog.rejects OWNER TO exilog;

--
-- Name: unknown; Type: TABLE; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE TABLE unknown (
    server character varying(32) NOT NULL,
    message_id character(23) NOT NULL,
    "timestamp" bigint NOT NULL,
    line character varying(255) NOT NULL
);


ALTER TABLE exilog.unknown OWNER TO exilog;

--
-- Name: deferrals_primary; Type: CONSTRAINT; Schema: exilog; Owner: exilog; Tablespace:
--

ALTER TABLE ONLY deferrals
    ADD CONSTRAINT deferrals_primary PRIMARY KEY (server, message_id, "timestamp", rcpt, rcpt_final);


--
-- Name: deliveries_primary; Type: CONSTRAINT; Schema: exilog; Owner: exilog; Tablespace:
--

ALTER TABLE ONLY deliveries
    ADD CONSTRAINT deliveries_primary PRIMARY KEY (server, message_id, "timestamp", rcpt, rcpt_final);


--
-- Name: errors_primary; Type: CONSTRAINT; Schema: exilog; Owner: exilog; Tablespace:
--

ALTER TABLE ONLY errors
    ADD CONSTRAINT errors_primary PRIMARY KEY (server, message_id, "timestamp", rcpt, rcpt_final);


--
-- Name: heartbeats_pkey; Type: CONSTRAINT; Schema: exilog; Owner: exilog; Tablespace:
--

ALTER TABLE ONLY heartbeats
    ADD CONSTRAINT heartbeats_pkey PRIMARY KEY (server, "timestamp");


--
-- Name: primary; Type: CONSTRAINT; Schema: exilog; Owner: exilog; Tablespace:
--

ALTER TABLE ONLY messages
    ADD CONSTRAINT "primary" PRIMARY KEY (server, message_id);


--
-- Name: queue_primary; Type: CONSTRAINT; Schema: exilog; Owner: exilog; Tablespace:
--

ALTER TABLE ONLY queue
    ADD CONSTRAINT queue_primary PRIMARY KEY (server, message_id);


--
-- Name: rejects_unique; Type: CONSTRAINT; Schema: exilog; Owner: exilog; Tablespace:
--

ALTER TABLE ONLY rejects
    ADD CONSTRAINT rejects_unique UNIQUE (server, "timestamp", host_addr, errmsg);


--
-- Name: unknown_primary; Type: CONSTRAINT; Schema: exilog; Owner: exilog; Tablespace:
--

ALTER TABLE ONLY unknown
    ADD CONSTRAINT unknown_primary PRIMARY KEY (server, message_id, "timestamp", line);


--
-- Name: bounce_parent; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX bounce_parent ON messages USING btree (bounce_parent);


--
-- Name: deferrals_host_addr; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX deferrals_host_addr ON deferrals USING btree (host_addr);


--
-- Name: deferrals_message_id; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX deferrals_message_id ON deferrals USING btree (message_id);


--
-- Name: deferrals_rcpt; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX deferrals_rcpt ON deferrals USING btree (rcpt);


--
-- Name: deferrals_rcpt_final; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX deferrals_rcpt_final ON deferrals USING btree (rcpt_final);


--
-- Name: deferrals_server; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX deferrals_server ON deferrals USING btree (server);


--
-- Name: deferrals_server_message_id; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX deferrals_server_message_id ON deferrals USING btree (server, message_id);


--
-- Name: deferrals_timestamp; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX deferrals_timestamp ON deferrals USING btree ("timestamp");


--
-- Name: deliveries_host_addr; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX deliveries_host_addr ON deliveries USING btree (host_addr);


--
-- Name: deliveries_message_id; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX deliveries_message_id ON deliveries USING btree (message_id);


--
-- Name: deliveries_rcpt; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX deliveries_rcpt ON deliveries USING btree (rcpt);


--
-- Name: deliveries_rcpt_final; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX deliveries_rcpt_final ON deliveries USING btree (rcpt_final);


--
-- Name: deliveries_server; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX deliveries_server ON deliveries USING btree (server);


--
-- Name: deliveries_server_message_id; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX deliveries_server_message_id ON deliveries USING btree (server, message_id);


--
-- Name: deliveries_timestamp; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX deliveries_timestamp ON deliveries USING btree ("timestamp");


--
-- Name: errors_host_addr; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX errors_host_addr ON errors USING btree (host_addr);


--
-- Name: errors_message_id; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX errors_message_id ON errors USING btree (message_id);


--
-- Name: errors_rcpt; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX errors_rcpt ON errors USING btree (rcpt);


--
-- Name: errors_rcpt_final; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX errors_rcpt_final ON errors USING btree (rcpt_final);


--
-- Name: errors_server; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX errors_server ON errors USING btree (server);


--
-- Name: errors_server_message_id; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX errors_server_message_id ON errors USING btree (server, message_id);


--
-- Name: errors_timestamp; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX errors_timestamp ON errors USING btree ("timestamp");


--
-- Name: host_addr; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX host_addr ON messages USING btree (host_addr);


--
-- Name: mailfrom; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX mailfrom ON messages USING btree (mailfrom);


--
-- Name: message_id; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX message_id ON messages USING btree (message_id);


--
-- Name: messages_server_message_id; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX messages_server_message_id ON messages USING btree (server, message_id);


--
-- Name: msgid; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX msgid ON messages USING btree (msgid);


--
-- Name: queue_action; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX queue_action ON queue USING btree (action);


--
-- Name: queue_frozen; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX queue_frozen ON queue USING btree (frozen);


--
-- Name: queue_mailfrom; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX queue_mailfrom ON queue USING btree (mailfrom);


--
-- Name: queue_message_id; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX queue_message_id ON queue USING btree (message_id);


--
-- Name: queue_msgid; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX queue_msgid ON queue USING btree (msgid);


--
-- Name: queue_server; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX queue_server ON queue USING btree (server);


--
-- Name: queue_server_message_id; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX queue_server_message_id ON queue USING btree (server, message_id);


--
-- Name: queue_spool_path; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX queue_spool_path ON queue USING btree (spool_path);


--
-- Name: queue_timestamp; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX queue_timestamp ON queue USING btree ("timestamp");


--
-- Name: rejects_host_addr; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX rejects_host_addr ON rejects USING btree (host_addr);


--
-- Name: rejects_mailfrom; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX rejects_mailfrom ON rejects USING btree (mailfrom);


--
-- Name: rejects_message_id; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX rejects_message_id ON rejects USING btree (message_id);


--
-- Name: rejects_rcpt; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX rejects_rcpt ON rejects USING btree (rcpt);


--
-- Name: rejects_server; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX rejects_server ON rejects USING btree (server);


--
-- Name: rejects_server_message_id; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX rejects_server_message_id ON rejects USING btree (server, message_id);


--
-- Name: rejects_timestamp; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX rejects_timestamp ON rejects USING btree ("timestamp");


--
-- Name: server; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX server ON messages USING btree (server);


--
-- Name: timestamp; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX "timestamp" ON messages USING btree ("timestamp");


--
-- Name: unknown_message_id; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX unknown_message_id ON unknown USING btree (message_id);


--
-- Name: unknown_server; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX unknown_server ON unknown USING btree (server);


--
-- Name: unknown_server_message_id; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX unknown_server_message_id ON unknown USING btree (server, message_id);


--
-- Name: unknown_timestamp; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX unknown_timestamp ON unknown USING btree ("timestamp");


--
-- Name: user; Type: INDEX; Schema: exilog; Owner: exilog; Tablespace:
--

CREATE INDEX "user" ON messages USING btree ("user");


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

