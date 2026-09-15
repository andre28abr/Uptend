-- Banco fictício INSEGURO (lab) — PII em texto plano, senha sem hash, tabelas sem PK.
DROP DATABASE IF EXISTS loja_insegura;
CREATE DATABASE loja_insegura;
\c loja_insegura
CREATE TABLE clientes (
  id serial PRIMARY KEY,
  nome_completo text, email varchar(255), cpf text, rg text,
  telefone text, endereco text, cep text, data_nascimento text,
  senha text, cartao_credito text, cvv text
);
CREATE TABLE pedidos (            -- sem chave primária
  id integer, cliente_id integer, valor numeric, cartao text
);
CREATE TABLE funcionarios (       -- sem chave primária
  matricula integer, nome_completo text, salario text, cpf text, senha_login text
);
CREATE TABLE logs_acesso (        -- sem chave primária
  usuario text, ip text, token text, api_key text
);
INSERT INTO clientes (nome_completo,email,cpf,senha,cartao_credito,cvv)
  VALUES ('Fulano de Tal','f@ex.com','111.222.333-44','123456','4111111111111111','123');
