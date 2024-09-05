// script{
//     use 0x12::collection as coll;
//     use std::debug;
//     use std::signer;

//     fun main_resource(account: signer){
//         let addr = signer::address_of(&account);
//         // OR
//         // let addr = @0x63;
        
//         coll::destroy(&account);
//         coll::start_collection(&account);
//         let ea = coll::exists_at(addr);
//         debug::print(&ea);
//         coll::add_item(&account);
//         coll::add_item(&account);
//         coll::add_item(&account);
//         let lsize = coll::size(&account);
//         debug::print(&lsize);
//     }
// }