create or replace package payment_processing_pack is

  -- Author  : D.KIVILEV
  -- Created : 04.07.2023 10:53:33
  -- Purpose :

  procedure processing(p_bulk_size number);

end payment_processing_pack;
/
create or replace package body payment_processing_pack is

  function check_client_and_get_wallet(p_client_id client.client_id%type) return wallet.wallet_id%type is
    v_client_is_active client.is_active%type;
    v_client_blocked   client.is_blocked%type;
    v_wallet_id        wallet.wallet_id%type;
    v_wallet_status_id wallet.status_id%type;
  begin
    select /*+ index(w1 WALLET_CLIENT_FK) index(w2 WALLET_CLIENT_FK)*/
           cl.is_active
          ,cl.is_blocked
          ,w.wallet_id
          ,w.status_id
      into v_client_is_active
          ,v_client_blocked
          ,v_wallet_id
          ,v_wallet_status_id
      from client cl
      left join wallet w
        on w.client_id = cl.client_id
     where cl.client_id = p_client_id;

    if (v_client_is_active = client_api_pack.c_inactive or v_client_blocked = client_api_pack.c_not_blocked or
       v_wallet_status_id = wallet_api_pack.c_wallet_status_blocked) then
      raise_application_error(exception_pack.c_error_code_payment_cant_be_processed,
                              exception_pack.c_error_msg_payment_cant_be_processed);
    end if;

    return v_wallet_id;

  end;


  procedure processing(p_bulk_size number) is
    v_payment_ids    t_number_array;
    v_wallet_from_id wallet.wallet_id%type;
    v_wallet_to_id   wallet.wallet_id%type;
  begin
    select p.payment_id
      bulk collect
      into v_payment_ids
      from payment p
     where p.status = payment_api_pack.c_created
       and rownum <= p_bulk_size
       for update skip locked;

    if v_payment_ids is empty then
      return;
    end if;

    for p in (select /*+ cardinality(pi 1000) leading(p pi)*/
               p.payment_id
              ,p.currency_id
              ,p.summa
              ,p.from_client_id
              ,p.to_client_id
                from table(v_payment_ids) pi
                join payment p
                  on p.payment_id = value(pi)) loop
      begin
        dbms_application_info.set_action(action_name => 'process payment_id: ' || p.payment_id);

        v_wallet_from_id := check_client_and_get_wallet(p.from_client_id);
        v_wallet_to_id   := check_client_and_get_wallet(p.to_client_id);

        account_api_pack.transfer_money(p_wallet_from_id => v_wallet_from_id,
                                        p_wallet_to_id   => v_wallet_to_id,
                                        p_currency_id    => p.currency_id,
                                        p_summa          => p.summa);

        payment_api_pack.successful_finish_payment(p_payment_id => p.payment_id);
      exception
        when others then
          payment_api_pack.fail_payment(p_payment_id => p.payment_id,
                                        p_reason     => substr(sqlerrm || utl_tcp.crlf ||
                                                               dbms_utility.format_error_stack,
                                                               1,
                                                               200));
      end;
      dbms_application_info.set_action(action_name => null);

    end loop;

    commit;

  end;

end payment_processing_pack;
/
