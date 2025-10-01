CREATE INDEX payment_status ON payment (status) LOCAL online;
/
CREATE unique INDEX wallet_client_id on wallet (client_id) online;
/
