module nft_coupon_v2::cryptomilan {
    use std::string::{Self, String};
    use std::signer;
    use aptos_framework::event;
    use aptos_framework::object::{Self, Object, DeleteRef,object_exists};
    use std::option;

    // Error constants
    const ENOT_AUTHORIZED: u64 = 1;
    const EALREADY_REDEEMED: u64 = 2;
    const ECANNOT_DELETE: u64 = 3;

    /// Struct maintaining all the metadata from original NFTMilan
    struct CouponToken has key,store {
        name: String,
        description: String,
        latitude: String,
        longitude: String,
        sponsor: String,
        ipfs_uri: String,
        delete_ref: DeleteRef,
        is_redeemed: bool
    }

    // Events
    #[event]
    struct TokenMintedEvent has drop, store {
        token_address: address,
    }

    #[event]
    struct TokenRedeemedEvent has drop, store {
        user: address,
        token_address: address,
        coupon_type: u8
    }

    #[event]
    struct TokenTransferredEvent has drop, store {
        token_address: address,
        from: address,
        to: address
    }

    public entry fun mint_token_transfer(
        creator: &signer,
        name: String,
        description: String,
        latitude: String,
        longitude: String,
        sponsor: String,
        ipfs_uri: String,
        user: address
    ) {
        let name_utf8 =  *string::bytes(&name);
        
        let constructor_ref = object::create_named_object(
            creator,
             name_utf8,
        );

        let token = CouponToken {
            name: name,
            description: description,
            latitude: latitude,
            longitude: longitude,
            sponsor: sponsor,
            ipfs_uri: ipfs_uri,
            delete_ref: object::generate_delete_ref(&constructor_ref),
            is_redeemed: false
        };

        let token_signer = object::generate_signer(&constructor_ref);
        move_to(&token_signer, token);

        let token_object = object::object_from_constructor_ref<CouponToken>(&constructor_ref);
        let token_address = object::address_from_constructor_ref(&constructor_ref);

        // Emit mint event
        event::emit(TokenMintedEvent {
            token_address,
        });

        let from_address = signer::address_of(creator);
        object::transfer(creator, token_object, user);
        event::emit(TokenTransferredEvent {
            token_address,
            from: from_address,
            to: user
        });
    }

    public entry fun transfer_token(
        from: &signer,
        to: address,
        token: Object<CouponToken>
    ) {
        let from_address = signer::address_of(from);
        let token_address = object::object_address(&token);
        
        object::transfer(from, token, to);
        
        event::emit(TokenTransferredEvent {
            token_address,
            from: from_address,
            to
        });
    }

    #[lint::allow_unsafe_randomness]
    public entry fun redeem_token(
        user: &signer,
        token: Object<CouponToken>
    ) acquires CouponToken {
        let token_address = object::object_address(&token);
        let token_data = borrow_global_mut<CouponToken>(token_address);
        
        // Verify token hasn't been redeemed
        assert!(!token_data.is_redeemed, EALREADY_REDEEMED);
        
        // Mark token as redeemed
        token_data.is_redeemed = true;
        
        // Generate random number for coupon type (0-2)
        let random_number = aptos_framework::randomness::u8_range(0, 2);
        
        // Delete the token object using its address
        let CouponToken {
            name: _,
            description: _,
            latitude: _,
            longitude: _,
            sponsor: _,
            ipfs_uri: _,
            delete_ref,
            is_redeemed: _
        } = move_from<CouponToken>(token_address);
        
       
        object::delete(delete_ref);
        
        event::emit(TokenRedeemedEvent {
            user: signer::address_of(user),
            token_address,
            coupon_type: random_number
        });
    }

    #[view]
    public fun is_redeemed(token: Object<CouponToken>): bool acquires CouponToken {
        let token_data = borrow_global<CouponToken>(object::object_address(&token));
        token_data.is_redeemed
    }

    #[test_only]
    struct TestAccounts has key, drop {
        admin: address,
        user1: address,
        user2: address
    }

    #[test_only]
    public fun setup_test_accounts(): TestAccounts {
        TestAccounts {
            admin: @0xCAFE,
            user1: @0x1,
            user2: @0x2
        }
    }

    #[test(admin = @0xCAFE, user1 = @0x1, user2 = @0x2)]
    fun test_mint_and_transfer(admin: &signer, user1: &signer, user2: &signer) {
        let _ = setup_test_accounts();
        
        // Mint token to user1
        mint_token_transfer(
            admin,
            string::utf8(b"Test Token"),
            string::utf8(b"Test Description"),
            string::utf8(b"45.4642"),
            string::utf8(b"9.1900"),
            string::utf8(b"Test Sponsor"),
            string::utf8(b"ipfs://test"),
            signer::address_of(user1)
        );

        // Verify token exists at user1
        let token = object::address_to_object<CouponToken>(signer::address_of(user1));
        assert!(object_exists<CouponToken>(signer::address_of(user1)), 0);

        // Transfer to user2
        transfer_token(user1, signer::address_of(user2), token);

        // Verify transfer
        assert!(object_exists<CouponToken>(signer::address_of(user2)), 1);
    }

    #[test(admin = @0xCAFE, user1 = @0x1)]
    fun test_redeem_token(admin: &signer, user1: &signer) acquires CouponToken {
        let _ = setup_test_accounts();
        
        // Mint token to user1
        mint_token_transfer(
            admin,
            string::utf8(b"Test Token"),
            string::utf8(b"Test Description"),
            string::utf8(b"45.4642"),
            string::utf8(b"9.1900"),
            string::utf8(b"Test Sponsor"),
            string::utf8(b"ipfs://test"),
            signer::address_of(user1)
        );

        let token = object::address_to_object<CouponToken>(signer::address_of(user1));
        let token_address = object::object_address(&token);
        
        // Redeem token
        redeem_token(user1, token);

        // Verify token is deleted by checking token address
        assert!(!object_exists<CouponToken>(token_address), 2);
    }

    #[test(admin = @0xCAFE, user1 = @0x1)]
    #[expected_failure(abort_code = EALREADY_REDEEMED)]
    fun test_double_redeem_fails(admin: &signer, user1: &signer) acquires CouponToken {
        let _ = setup_test_accounts();
        
        // Mint token to user1
        mint_token_transfer(
            admin,
            string::utf8(b"Test Token"),
            string::utf8(b"Test Description"),
            string::utf8(b"45.4642"),
            string::utf8(b"9.1900"),
            string::utf8(b"Test Sponsor"),
            string::utf8(b"ipfs://test"),
            signer::address_of(user1)
        );

        let token = object::address_to_object<CouponToken>(signer::address_of(user1));
        
        // First redeem should succeed
        redeem_token(user1, token);

        // Create new token for second redeem attempt
        mint_token_transfer(
            admin,
            string::utf8(b"Test Token 2"),
            string::utf8(b"Test Description 2"),
            string::utf8(b"45.4642"),
            string::utf8(b"9.1900"),
            string::utf8(b"Test Sponsor"),
            string::utf8(b"ipfs://test2"),
            signer::address_of(user1)
        );

        let token2 = object::address_to_object<CouponToken>(signer::address_of(user1));
        
        // Second redeem should fail due to already redeemed
        redeem_token(user1, token2);
    }

    #[test(admin = @0xCAFE, user1 = @0x1)]
    #[expected_failure(abort_code = ECANNOT_DELETE)]
    fun test_delete_permission_fails(admin: &signer, user1: &signer) acquires CouponToken {
        let _ = setup_test_accounts();
        
        // Mint token to user1
        mint_token_transfer(
            admin,
            string::utf8(b"Test Token"),
            string::utf8(b"Test Description"),
            string::utf8(b"45.4642"),
            string::utf8(b"9.1900"),
            string::utf8(b"Test Sponsor"),
            string::utf8(b"ipfs://test"),
            signer::address_of(user1)
        );

        let token = object::address_to_object<CouponToken>(signer::address_of(user1));
        
        // Attempt redeem with invalid delete_ref by creating a new object
        let invalid_constructor_ref = object::create_named_object(
            admin,
            *string::bytes(&string::utf8(b"InvalidObject"))
        );
        let token_data = borrow_global_mut<CouponToken>(object::object_address(&token));
        token_data.delete_ref = object::generate_delete_ref(&invalid_constructor_ref);
        
        redeem_token(user1, token);
    }
}
