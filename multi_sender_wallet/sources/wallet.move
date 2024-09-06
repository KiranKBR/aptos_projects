module wallet::MultiSender
{
    use 0x1::coin;
    use 0x1::aptos_coin::AptosCoin; 
    use 0x1::aptos_account;
    use 0x1::vector;
    use 0x1::signer;

    const E_NOT_ENOUGH_COINS:u64 = 101;

    public entry fun ms_transfer(from: &signer,to: vector<address>, amount:u64)  
    {
        let size:u64 = vector::length(&to);
        let from_acc_balance:u64 = coin::balance<AptosCoin>(signer::address_of(from));

        assert!( amount*size <= from_acc_balance, E_NOT_ENOUGH_COINS);

        let i=0;
        while(i < size)
        {
            let to_address = *vector::borrow(& to,(i as u64));
            aptos_account::transfer(from,to_address,amount); 
            i=i+1;
        };
    }
}