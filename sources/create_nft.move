module cryptomilan::nft_milan {
    use std::string::{Self, String};
    use std::signer; 
    use aptos_framework::event;
    use aptos_token_objects::collection;
    use aptos_token_objects::token::{Self, BurnRef};
    use aptos_framework::object;
    use std::option;

    // Errors
    const ENOT_AUTHORIZED: u64 = 1;
    const ECOLLECTION_NOT_INITIALIZED: u64 = 2;

    // Struct to store NFT data
    struct NFTMilan has key {
        prob_of_default: u64,
        loss_given_default: u64,
        risk_score: u64,
        exposure_at_default: u64,
        underwritten: bool,
        metadata: NFTMilanMetadata,
        burn_ref: BurnRef
    }

    // Struct to store NFT metadata
    struct NFTMilanMetadata has copy, drop, store {
        name: String,
        description: String,
        lattitude:String,
        longitude:String,
        sponsor:String,
        ipfs_uri:String
    }

    // Events
    #[event]
    struct NFTMintedEvent has drop, store {
        token_address: address,
        metadata: NFTMilanMetadata,
    }

    #[event]
    struct NFTTransferredEvent has drop, store {
        token_address: address,
        from: address,
        to: address,
    }

    // Initialize the collection
    public entry fun initialize_collection(creator: &signer) {
        let description = string::utf8(b"CoinDCX Unfold");
        let name = string::utf8(b"NFT_Unfold");
        let uri = string::utf8(b"https://");

        collection::create_unlimited_collection(
            creator,
            description,
            name,
            option::none(),
            uri,
        );
    }

    // Mint a new NFT
    public entry fun mint_nft(
        creator: &signer, 
        name: String,
        description: String,
        lattitude:String,
        longitude:String,
        sponsor:String,
        ipfs_uri:String
    ) {
        let collection_name = string::utf8(b"NFT_Unfold");
        let user_address=signer::address_of(creator);
        let metadata = NFTMilanMetadata {
            name,
            description,
            lattitude,
            longitude,
            sponsor,
            ipfs_uri
        };

        let token_constructor_ref = token::create_named_token(
            creator,
            collection_name,
            metadata.description,
            metadata.name,
            option::none(),
            string::utf8(b"https:nft/"),
        );

        let token_signer = object::generate_signer(&token_constructor_ref);
        let burn_ref = token::generate_burn_ref(&token_constructor_ref);
        let token = NFTMilan {
            prob_of_default: 0,
            loss_given_default: 0,
            risk_score: 0,
            exposure_at_default: 0,
            underwritten: false,
            metadata,
            burn_ref
        };

        move_to(&token_signer, token);

        let token_address = signer::address_of(&token_signer);
        event::emit(NFTMintedEvent { token_address, metadata });

        let token_object = object::address_to_object<NFTMilan>(token_address);
        object::transfer(creator, token_object, user_address);
    }

     public entry fun transfer_nft(from: &signer, to: address, token_address: address) {
        let token_object = object::address_to_object<NFTMilan>(token_address);
        let from_address = signer::address_of(from);
        object::transfer(from, token_object, to);
        event::emit(NFTTransferredEvent { token_address, from: from_address, to });
    }

    // Update NFT data
    public entry fun update_nft_data(
        _updater: &signer,
        token_address: address,
        prob_of_default: u64,
        loss_given_default: u64,
        risk_score: u64,
        exposure_at_default: u64,
    ) acquires NFTMilan {
        // Add authorization check here if needed
        let nft = borrow_global_mut<NFTMilan>(token_address);
        nft.prob_of_default = prob_of_default;
        nft.loss_given_default = loss_given_default;
        nft.risk_score = risk_score;
        nft.exposure_at_default = exposure_at_default;
        nft.underwritten = true;
    }

    // Getter function
    public fun get_nft_data(token_address: address): (u64, u64, u64, u64, bool, NFTMilanMetadata) acquires NFTMilan {
        let nft = borrow_global<NFTMilan>(token_address);
        (
            nft.prob_of_default,
            nft.loss_given_default,
            nft.risk_score,
            nft.exposure_at_default,
            nft.underwritten,
            nft.metadata
        )
    }
    public fun is_underwritten(token_address: address): bool acquires NFTMilan {
        let nft = borrow_global<NFTMilan>(token_address);
        nft.underwritten
    }

    // public entry 

    // // Function to reset underwritten status
    // public entry fun reset_underwritten(
    //     admin: &signer,
    //     token_address: address
    // ) acquires NFTMilan {
    //     // Add authorization check to ensure only admin can reset
    //     let admin_address = signer::address_of(admin);
    //     assert!(admin_address == @qiro, ENOT_AUTHORIZED);
        
    //     let nft = borrow_global_mut<NFTMilan>(token_address);
    //     nft.underwritten = false;
        
    //     // Reset related fields to their default values
    //     nft.prob_of_default = 0;
    //     nft.loss_given_default = 0;
    //     nft.risk_score = 0;
    //     nft.exposure_at_default = 0;
    // }
    


    // fun determine_gift_type(random_number: u32): GiftType {
    // match (random_number) {
    //     0 => GiftType::SwiggyCoupon,
    //     1 => GiftType::OlaCoupon,
    //     2 => GiftType::UberCoupon,
    //     _ => GiftType::SwiggyCoupon, 
    // }
// }
    // Function to burn an NFT (simplified)
    // public entry fun burn_nft(owner: &signer, token_address: address) acquires NFTMilan {
    //     let nft = move_from<NFTMilan>(token_address);
    //     let token_object = object::address_to_object<NFTMilan>(token_address);
    //     object::delete(token_object);
    // }

    


//     fun determine_gift_type(random_number: u32): GiftType {
//     match (random_number) {
//         0 => GiftType::SwiggyCoupon,
//         1 => GiftType::OlaCoupon,
//         2 => GiftType::UberCoupon,
//         _ => GiftType::SwiggyCoupon, 
//     }
// }

    #[lint::allow_unsafe_randomness]
    #[view]
    public fun redeem(): u8  {
        
        let random_number=aptos_framework::randomness::u8_range(0, 2);
        return random_number
        

    }
}
