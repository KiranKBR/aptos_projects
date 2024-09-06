module my_addrx::BasicTokens {
    use std::error;
    use std::signer;

    /// Error codes
    const ENOT_MODULE_OWNER: u64 = 0;
    const EINSUFFICIENT_BALANCE: u64 = 1;
    const EALREADY_HAS_BALANCE: u64 = 2;
    const EALREADY_INITIALIZED: u64 = 3;
    const EEQUAL_ADDR: u64 = 4;

    struct Coin has store, drop {
        value: u64
    }

    struct Balance has key {
        coin: Coin
    }

    public fun createCoin(v: u64): Coin {
        let coin = Coin { value: v };
        return coin
    }

    public fun publish_balance(account: &signer) {
        let empty_coin = Coin { value: 0 };
        assert!(
            !exists<Balance>(signer::address_of(account)),
            error::already_exists(EALREADY_HAS_BALANCE)
        );
        move_to(account, Balance { coin: empty_coin });
        // move_to(account, empty_coin); // Coin does not have key ability only key abilities stored in account storage

    }

    public fun mint<CoinType: drop>(mint_addr: address, amount: u64) acquires Balance {
        // deposit(mint_addr, Coin { value: amount });
        let balance = balance_of(mint_addr);

        // Add the deposited amount to the balance
        let balance_ref = &mut borrow_global_mut<Balance>(mint_addr).coin.value;
        // let Coin { value } = check;
        *balance_ref = balance + amount;
    }

    public fun burn(burn_addr: address, amount: u64) acquires Balance {
        // let Coin { value: _ } = withdraw(burn_addr, amount);
        let balance = balance_of(burn_addr);
        assert!(balance >= amount, EINSUFFICIENT_BALANCE);

        // Update the balance in storage
        let balance_ref = &mut borrow_global_mut<Balance>(burn_addr).coin.value;
        *balance_ref = balance - amount;
    }

    public fun balance_of(owner: address): u64 acquires Balance {
        borrow_global<Balance>(owner).coin.value
    }

    // Transfer function with signer verification for 'from' account
    public fun transfer(from: &signer, to_addr: address, amount: u64) acquires Balance {
        let from_addr = signer::address_of(from);
        assert!(from_addr != to_addr, EEQUAL_ADDR);

        // Withdraw from the account controlled by 'from' signer
        // let check = withdraw(from, amount);
        let balance = balance_of(from_addr);
        assert!(balance >= amount, EINSUFFICIENT_BALANCE);
        let balance_ref = &mut borrow_global_mut<Balance>(from_addr).coin.value;
        *balance_ref = balance - amount;

        // Deposit the amount into the 'to' address
        // deposit(to, check);
        let balance = balance_of(to_addr);

        // Add the deposited amount to the balance
        let balance_ref = &mut borrow_global_mut<Balance>(to_addr).coin.value;
        // let Coin { value } = check;
        *balance_ref = balance + amount;

    }

    // Withdraw function updated to use signer for authorization
    public fun withdraw(from: &signer, amount: u64): Coin acquires Balance {
        let from_addr = signer::address_of(from);

        // Check the balance and perform withdrawal
        let balance = balance_of(from_addr);
        assert!(balance >= amount, EINSUFFICIENT_BALANCE);

        // Update the balance in storage
        let balance_ref = &mut borrow_global_mut<Balance>(from_addr).coin.value;
        *balance_ref = balance - amount;

        Coin { value: amount }
    }

    // Deposit function to verify correct authorization using signer
    public fun deposit(to: &signer, check: Coin) acquires Balance {
        let to_addr = signer::address_of(to);

        // Retrieve the current balance
        let balance = balance_of(to_addr);

        // Add the deposited amount to the balance
        let balance_ref = &mut borrow_global_mut<Balance>(to_addr).coin.value;
        let Coin { value } = check;
        *balance_ref = balance + value;
    }
}

module my_addrx::Staking {
    use std::signer;
    use aptos_framework::account;
    /// Error codes
    const EINSUFFICIENT_STAKE: u64 = 0;
    const EALREADY_STAKED: u64 = 1;
    const EINVALID_UNSTAKE_AMOUNT: u64 = 2;
    const EINVALID_REWARD_AMOUNT: u64 = 3;
    const EINVALID_APY: u64 = 4;
    const EINSUFFICIENT_BALANCE: u64 = 5;
    const DEFAULT_APY: u64 = 1000; //10% APY per year

    struct StakedBalance has store, key {
        staked_balance: u64

    }

    public fun stake(acc_own: &signer, amount: u64) {
        let from = signer::address_of(acc_own);
        let balance = my_addrx::BasicTokens::balance_of(from);
        assert!(balance >= amount, EINSUFFICIENT_BALANCE);
        assert!(!exists<StakedBalance>(from), EALREADY_STAKED);
        my_addrx::BasicTokens::withdraw(acc_own, amount);
        let staked_balance = StakedBalance { staked_balance: amount };
        move_to(acc_own, staked_balance);
    }

    public fun unstake(acc_own: &signer, amount: u64) acquires StakedBalance {
        let from = signer::address_of(acc_own);
        let staked_balance = borrow_global_mut<StakedBalance>(from);
        let staked_amount = staked_balance.staked_balance;
        assert!(staked_amount >= amount, EINVALID_UNSTAKE_AMOUNT);
        let coins = my_addrx::BasicTokens::createCoin(staked_amount);
        my_addrx::BasicTokens::deposit(acc_own, coins);
        staked_balance.staked_balance = staked_balance.staked_balance - amount;
    }

    public fun claim_rewards(acc_own: &signer) acquires StakedBalance {
        let from = signer::address_of(acc_own);
        let staked_balance = borrow_global_mut<StakedBalance>(from);
        let staked_amount = staked_balance.staked_balance;
        assert!(staked_amount > 0, EINSUFFICIENT_STAKE);
        let apy = DEFAULT_APY;
        let reward_amount = (staked_amount * apy) / (10000);
        let coins = my_addrx::BasicTokens::createCoin(reward_amount);
        my_addrx::BasicTokens::deposit(acc_own, coins);
    }

    #[test(alice = @0x11, bob = @0x2)]
    public entry fun test_staking(alice: signer, bob: signer) acquires StakedBalance {
        account::create_account_for_test(signer::address_of(&alice));
        account::create_account_for_test(signer::address_of(&bob));

        // Publish balance for Alice and Bob
        my_addrx::BasicTokens::publish_balance(&alice);
        my_addrx::BasicTokens::publish_balance(&bob);

        // Mint some tokens to Alice
        my_addrx::BasicTokens::mint<my_addrx::BasicTokens::Coin>(
            signer::address_of(&bob), 1000
        );
        my_addrx::BasicTokens::mint<my_addrx::BasicTokens::Coin>(
            signer::address_of(&alice), 1000
        );

        // Alice stakes some tokens
        stake(&alice, 500);

        // Check that Alice's staked balance is correct
        let alice_resource = borrow_global<StakedBalance>(signer::address_of(&alice));
        assert!(alice_resource.staked_balance == 500, 100);

        // // Alice tries to stake again (should fail)
        // stake(&alice, 500);

        // // Bob tries to unstake from Alice's account (should fail)
        // unstake(&bob, 200);

        // // Alice unstakes some tokens
        unstake(&alice, 200);

        // Check that Alice's staked balance is correct
        let alice_resource = borrow_global<StakedBalance>(signer::address_of(&alice));
        assert!(alice_resource.staked_balance == 300, 100);

        // // Alice claims rewards
        claim_rewards(&alice);
    }
}
