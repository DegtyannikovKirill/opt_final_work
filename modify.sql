CREATE INDEX payment_status_createDtime_payment_id ON payment (status,create_dtime ,payment_id) LOCAL;
/
create unique index client_client_id_is_active_is_blocked on client(client_id, is_active, is_blocked)
/
CREATE unique INDEX wallet_client_id_wallet_id_status_id on wallet (client_id, wallet_id, status_id)
/
