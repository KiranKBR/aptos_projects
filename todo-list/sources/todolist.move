module todolist_addr::todolist {
    use std::signer;
    use aptos_framework::account;
    use aptos_framework::event;
    use aptos_std::table::{Self, Table};
    use std::string::String;

    //Errors
    const E_NOT_INITIALIZED: u64 = 0;
    const ETASK_DOESNT_EXIST: u64 = 2;
    const ETASK_IS_COMPLETED: u64 = 3;

    /// strut ToDOLilst
    struct ToDoList has key {
        tasks: Table<u64, Task>,
        task_counter: u64,
        set_task_event: event::EventHandle<Task>
    }

    ///struct Task
    struct Task has store, drop, copy {
        task_id: u64,
        address: address,
        content: String,
        completed: bool
    }

    public entry fun create_list(account: &signer) {
        let todo_list = ToDoList {
            tasks: table::new(),
            task_counter: 0,
            set_task_event: account::new_event_handle<Task>(account)
        };

        move_to(account, todo_list);
    }

    //add new task to list
    public entry fun add_task(account: &signer, content: String) acquires ToDoList {
        let signer_addrx = signer::address_of(account);
        assert!(exists<ToDoList>(signer_addrx), E_NOT_INITIALIZED);
        let todo_list = borrow_global_mut<ToDoList>(signer_addrx);
        let task_id = todo_list.task_counter + 1;
        let task = Task {
            task_id: task_id,
            address: signer_addrx,
            content: content,
            completed: false
        };
        todo_list.task_counter = task_id;
        table::upsert(&mut todo_list.tasks, task_id, task);
        event::emit_event<Task>(
            &mut borrow_global_mut<ToDoList>(signer_addrx).set_task_event,
            task
        );

    }

    ///complete the task
    public entry fun complete_task(account: &signer, task_id: u64) acquires ToDoList {
        //get signer address
        let signer_addrx = signer::address_of(account);

        //check if ToDoList exists
        assert!(exists<ToDoList>(signer_addrx), E_NOT_INITIALIZED);

        //get todo list from global storage
        let todo_list = borrow_global_mut<ToDoList>(signer_addrx);

        //check existance of task in todo list
        assert!(table::contains(&todo_list.tasks, task_id), ETASK_DOESNT_EXIST);

        //get task from todo list
        let task_record = table::borrow_mut(&mut todo_list.tasks, task_id);

        //check if task is completed
        assert!(task_record.completed == false, ETASK_IS_COMPLETED);

        //change task status to completed
        task_record.completed = true;
    }

    #[test_only]
    use std::string;
    #[test(admin = @0x123)]
    public entry fun test_flow(admin: signer) acquires ToDoList {
        // creates an admin @todolist_addr account for test
        account::create_account_for_test(signer::address_of(&admin));
        // initialize contract with admin account
        create_list(&admin);

        // creates a task by the admin account
        add_task(&admin, string::utf8(b"New Task"));
        let task_count =
            event::counter(
                &borrow_global<ToDoList>(signer::address_of(&admin)).set_task_event
            );
        let todo_list = borrow_global<ToDoList>(signer::address_of(&admin));

        assert!(task_count == todo_list.task_counter, 4);
        add_task(&admin, string::utf8(b"New Task another"));
        let todo_list = borrow_global<ToDoList>(signer::address_of(&admin));

        // add_task(&admin, string::utf8(b"New Task another")); //it will create error as it is modifying while todo_list has borrowed reference and same thing will happen with mutable borrow

        // let todo_list = borrow_global_mut<ToDoList>(signer::address_of(&admin));// freeze inference involve while getting a task from todo list

        assert!(todo_list.task_counter == 2, 5);
        let task_record = table::borrow(&todo_list.tasks, todo_list.task_counter - 1);
        assert!(task_record.task_id == 1, 6);
        assert!(task_record.completed == false, 7);
        assert!(task_record.content == string::utf8(b"New Task"), 8);
        assert!(task_record.address == signer::address_of(&admin), 9);

        // updates task as completed
        complete_task(&admin, 1);
        let todo_list = borrow_global<ToDoList>(signer::address_of(&admin));
        let task_record = table::borrow(&todo_list.tasks, 1);
        assert!(task_record.task_id == 1, 10);
        assert!(task_record.completed == true, 11);
        assert!(task_record.content == string::utf8(b"New Task"), 12);
        assert!(task_record.address == signer::address_of(&admin), 13);
    }

    #[test(admin = @0x123)]
    #[expected_failure(abort_code = E_NOT_INITIALIZED)]
    public entry fun account_can_not_update_task(admin: signer) acquires ToDoList {
        // creates an admin @todolist_addr account for test
        account::create_account_for_test(signer::address_of(&admin));
        // account can not toggle task as no list was created
        complete_task(&admin, 2);
    }
}
