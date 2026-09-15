-- Banco fictício SEGURO (lab) — PII cifrada, senha com hash, todas com PK, FK indexada.
DROP DATABASE IF EXISTS loja_segura;
CREATE DATABASE loja_segura;
\c loja_segura
CREATE TABLE clientes (
  id serial PRIMARY KEY,
  nome_encrypted bytea, email_encrypted bytea, cpf_encrypted bytea,
  telefone_encrypted bytea, senha_hash text
);
CREATE TABLE pedidos (
  id serial PRIMARY KEY,
  cliente_id integer REFERENCES clientes(id), valor numeric
);
CREATE INDEX idx_pedidos_cliente ON pedidos(cliente_id);
CREATE TABLE funcionarios (
  matricula integer PRIMARY KEY,
  nome_encrypted bytea, cpf_encrypted bytea, senha_hash text
);
CREATE TABLE auditoria (
  id serial PRIMARY KEY, acao text, quando timestamp
);
