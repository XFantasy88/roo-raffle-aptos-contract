module raffle::raffle
{
    use 0x1::signer;
    use 0x1::vector;
    use 0x1::coin;
    use 0x1::aptos_coin::AptosCoin; 
    use std::timestamp; 
    use std::string::String;
    use std::bcs;
    use std::hash;

    const ERR_NOT_INITIALIZED: u64 = 0;
    const ERR_NOT_OWNER: u64 = 1;
    const ERR_NOT_STARTED_YET: u64 = 2;
    const ERR_NOT_FINISHED_YET:u64 = 3;
    const ERR_FINISHED_ALREADY: u64 = 4;
    const ERR_INSUFFICIENT_BALANCE: u64 = 5;
    const ERR_ALL_TICKETS_SOLD: u64 = 6;
    const ERR_INVALID_TICKET_PRICE: u64 = 7;
    const ERR_INVALID_RAFFLE_ID: u64 = 7;
    const ERR_NO_PLAYER_JOINED: u64 = 8;
    const ERR_INCORRECT_RANDOMNESS: u64 = 9;
    const ERR_RAFFLE_FINISHED: u64 = 10;

    struct RaffleInfo has copy, store, drop {
        start_time: u64,
        end_time: u64,
        num_tickets: u64,
        ticket_price: u64,
        winning_ticket: u64,
        tickets_sold: u64,
        winner: address,
        image_url: String,
        title: String,
        description: String,
        ticket_index: u64,
        players: vector<address>
    }

    struct Raffle has key {
        raffles: vector<RaffleInfo>,
        owner: address,
    }

    public entry fun intialize(owner: &signer) {
        
        let addr = signer::address_of(owner);

        assert!(addr == @raffle, ERR_NOT_OWNER);

        move_to(owner, Raffle {
            owner: addr,
            raffles: vector::empty<RaffleInfo>()
        });
    }

    public fun assert_is_owner(addr: address) acquires Raffle {
        let owner = borrow_global<Raffle>(@raffle).owner;
        assert!(addr == owner, ERR_NOT_OWNER);
    }

    public fun assert_is_initialized() {
        assert!(exists<Raffle>(@raffle), ERR_NOT_INITIALIZED);
    }

    public entry fun start_raffle(owner: &signer, title: String, description: String, image_url: String, start_time: u64, end_time: u64, num_tickets: u64, ticket_price: u64) acquires Raffle {
        let owner_addr = signer::address_of(owner);

        assert_is_initialized();
        assert_is_owner(owner_addr);

        let raffle = borrow_global_mut<Raffle>(@raffle);

        let index = vector::length<RaffleInfo>(&raffle.raffles);

        let new_raffle = RaffleInfo {
            start_time: start_time,
            end_time: end_time,
            num_tickets: num_tickets,
            ticket_price: ticket_price,
            winning_ticket: 0,
            tickets_sold: 0,
            winner: @raffle,
            image_url: image_url,
            title: title,
            description: description,
            ticket_index: index,
            players: vector::empty<address>(),
        };


        vector::push_back(&mut raffle.raffles, new_raffle);
    }

    public entry fun play_raffle(user: &signer, amount: u64, index: u64) acquires Raffle {
        let addr = signer::address_of(user);
        let acc_balance: u64 = coin::balance<AptosCoin>(addr);

        assert!(amount <= acc_balance, ERR_INSUFFICIENT_BALANCE);

        let raffle = borrow_global_mut<Raffle>(@raffle);
        let length = vector::length<RaffleInfo>(&raffle.raffles);
        assert!(index < length, ERR_INVALID_RAFFLE_ID);
        let raffle_info = vector::borrow_mut(&mut raffle.raffles, index);

        assert!(amount == raffle_info.ticket_price, ERR_INVALID_TICKET_PRICE);

        let now = timestamp::now_seconds();

        assert!(now > raffle_info.start_time, ERR_NOT_STARTED_YET);
        assert!(now < raffle_info.end_time, ERR_FINISHED_ALREADY);
        assert!(raffle_info.tickets_sold < raffle_info.num_tickets, ERR_ALL_TICKETS_SOLD);

        coin::transfer<AptosCoin>(user, raffle.owner, amount);

        raffle_info.tickets_sold = raffle_info.tickets_sold + 1;
        vector::push_back(&mut raffle_info.players, addr);
    }

    public entry fun declare_winner(owner: &signer, index: u64) acquires Raffle {
        let addr = signer::address_of(owner);
        
        assert_is_initialized();
        assert_is_owner(addr);
        
        let raffle = borrow_global_mut<Raffle>(@raffle);
        let length = vector::length<RaffleInfo>(&raffle.raffles);
        assert!(index < length, ERR_INVALID_RAFFLE_ID);
        let raffle_info = vector::borrow_mut(&mut raffle.raffles, index);
        
        assert!(raffle_info.winner == @raffle, ERR_RAFFLE_FINISHED);
        let now = timestamp::now_seconds();
        assert!(now >= raffle_info.end_time, ERR_NOT_FINISHED_YET);
        let players = vector::length<address>(&raffle_info.players);

        assert!(players > 0, ERR_NO_PLAYER_JOINED);
        let winner = random_number(addr, players);
        let winner_addr = *vector::borrow(&raffle_info.players, winner);

        raffle_info.winning_ticket = winner;
        raffle_info.winner = winner_addr;
    }

    #[view]
    public fun get_raffle_count(): u64 acquires Raffle {
        assert_is_initialized();
        
        let raffle = borrow_global<Raffle>(@raffle);
        let length = vector::length(&raffle.raffles);

        return length
    }

    #[view]
    public fun get_raffle(index: u64): RaffleInfo acquires Raffle {
        assert_is_initialized();

        let raffle = borrow_global<Raffle>(@raffle);
        let length = vector::length(&raffle.raffles);

        assert!(index < length, ERR_INVALID_RAFFLE_ID);
        let raffle_info = vector::borrow(&raffle.raffles, index);

        return *raffle_info
    }

    fun random_number(user: address, max: u64): u64 {
        let x = bcs::to_bytes<address>(&user);
        let z = bcs::to_bytes<u64>(&timestamp::now_seconds());
        vector::append(&mut x,z);

        let entropy = hash::sha3_256(x);

        let num : u256 = 0;
        let max_256 = (max as u256);

        // Ugh, we have to manually deserialize this into a u128
        while (!vector::is_empty(&entropy)) {
            let byte = vector::pop_back(&mut entropy);
            num = num << 8;
            num = num + (byte as u256);
        };

        ((num % max_256) as u64)
    }
}