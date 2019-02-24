--
-- Portfolio users.  Self explanatory
--
create table portfolio_users (
--
-- Each user must have a name and a unique one at that.
--
  name  varchar(64) not null primary key,
--
-- Each user must have a password of at least eight characters
--
-- Note - this keeps the password in clear text in the database
-- which is a bad practice and only useful for illustration
--
-- The right way to do this is to store an encrypted password
-- in the database
--
  password VARCHAR(64) NOT NULL,
  constraint long_pass CHECK (password LIKE '________%')
);

--
--
-- User Portfolios
--
create table user_portfolios (
-- 
-- Owner must be a user
--
  owner varchar2(64) not null references portfolio_users(name) on delete cascade,
--
-- name of the portfolio
--
  name varchar2(200) not null,
--
-- Cash account for the user's portfolio
--
  cash number not null,
--
-- constraint saying that an owner+name combo must be unique
--
  CONSTRAINT own_name PRIMARY KEY (owner, name)
);

create table stock_holdings (
--
-- The stock symbol for the current stock holding
--
  symbol varchar(62) not null PRIMARY KEY,
--
-- The number of shares
--  
  num_shares number not null,
--
-- The owner of the stock holding
--
  owner varchar2(64) not null,
--
-- The portfolio in which the stock holding is in
-- 
  name varchar2(200) not null,
--
-- A stock holding must belong to an existing user_portfolio
-- 
  CONSTRAINT fk_owner_name FOREIGN KEY (owner, name) REFERENCES user_portfolios(owner,name)
);  

quit;
