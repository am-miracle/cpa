module cpa::project_manager;
    use std::string::{String};
    use sui::vec_map::{Self, VecMap};
    use std::u64::max;

    // ====== Structs ======

    /// Represents a project containing multiple tasks
    public struct Project has key {
        id: UID,
        name: String,
        owner: address,
        tasks: VecMap<ID, Task>, // Task ID => Task
        is_completed: bool,
    }

    /// Represents a single task in a project
    public struct Task has store {
        id: ID,
        name: String,
        duration: u64,
        start_time: u64,     // Set by off-chain CPA
        end_time: u64,       // Set by off-chain CPA
        is_critical: bool,   // Set by off-chain CPA
        is_completed: bool,
        depends_on: vector<ID>, // List of task IDs this task depends on
    }

    // ====== Constants (Errors) ======
    // const E_NOT_PROJECT_OWNER: u64 = 0;
    const E_TASK_NOT_FOUND: u64 = 1;
    const E_DEPENDENCY_NOT_MET: u64 = 2;
    const E_TASK_ALREADY_COMPLETED: u64 = 3;

    // ====== Public Functions ======

    /// Create a new project
    public fun create_project(
        owner: &mut TxContext,
        name: String,
        ctx: &mut TxContext
    ): Project {

        Project {
            id: object::new(ctx),
            name,
            owner: tx_context::sender(owner),
            tasks: vec_map::empty(),
            is_completed: false,
        }
    }

    /// Add a new task to the project
    public fun add_task(
        project: &mut Project,
        name: String,
        duration: u64,
        depends_on: vector<ID>,
        ctx: &mut TxContext
    ) {
        let task_uid = object::new(ctx);
        let task_id = object::uid_to_inner(&task_uid);

        let new_task = Task {
            id: task_id,
            name,
            duration,
            start_time: 0,      // To be updated off-chain
            end_time: 0,        // To be updated off-chain
            is_critical: false, // To be updated off-chain
            is_completed: false,
            depends_on,
        };
        vec_map::insert(&mut project.tasks, task_id, new_task);

        // We delete the UID since we only needed the ID
        object::delete(task_uid);
    }

    /// Update task schedule (called after off-chain CPA calculation)
    public fun update_task_schedule(
        project: &mut Project,
        task_id: ID,
        start_time: u64,
        end_time: u64,
        is_critical: bool,
    ) {
        assert!(vec_map::contains(&project.tasks, &task_id), E_TASK_NOT_FOUND);
        let task = vec_map::get_mut(&mut project.tasks, &task_id);
        task.start_time = start_time;
        task.end_time = end_time;
        task.is_critical = is_critical;
    }

    /// Mark a task as completed. it checks dependencies first
    public fun complete_task(
        project: &mut Project,
        task_id: ID,
    ) {
        assert!(vec_map::contains(&project.tasks, &task_id), E_TASK_NOT_FOUND);

        // check all dependencies are completed
        let mut i = 0;
        let dependencies = {
            let task = vec_map::get(&project.tasks, &task_id);
            assert!(!task.is_completed, E_TASK_ALREADY_COMPLETED);
            task.depends_on
        };

        while (i < vector::length(&dependencies)) {
            let dep_id = *vector::borrow(&dependencies, i);
            let dep_task = vec_map::get(&project.tasks, &dep_id);
            assert!(dep_task.is_completed, E_DEPENDENCY_NOT_MET);
            i = i + 1;
        };

        // update task and mark as completed
        let task = vec_map::get_mut(&mut project.tasks, &task_id);
        task.is_completed = true;
    }

    // ====== View Functions ======

    /// Get project info
    public fun get_project(project: &Project): (String, address, bool) {
        (project.name, project.owner, project.is_completed)
    }

    /// Get task info
    public fun get_task(project: &Project, task_id: ID): (String, u64, u64, u64, bool, bool) {
        assert!(vec_map::contains(&project.tasks, &task_id), E_TASK_NOT_FOUND);
        let task = vec_map::get(&project.tasks, &task_id);
        (
            task.name,
            task.duration,
            task.start_time,
            task.end_time,
            task.is_critical,
            task.is_completed
        )
    }

    public fun get_tasks(project: &Project): &VecMap<ID, Task> {
        &project.tasks
    }

    public fun is_task_completed(project: &Project, task_id: ID): bool {
        assert!(vec_map::contains(&project.tasks, &task_id), E_TASK_NOT_FOUND);
        let task = vec_map::get(&project.tasks, &task_id);
        task.is_completed
    }



    // ====== Helper Functions ======

    /// Check if caller is project owner
    public fun is_owner(project: &Project, caller: address): bool {
        project.owner == caller
    }

    public fun is_project_on_schedule(project: &Project, now: u64): bool {
        let mut max_late = 0u64;
        let keys = vec_map::keys(&project.tasks);
        let len = vector::length(&keys);
        let mut i = 0;
        while (i < len) {
            let key = *vector::borrow(&keys, i);
            let task = vec_map::get(&project.tasks, &key);
            if (!task.is_completed && task.end_time < now) {
                let late_by = now - task.end_time;
                max_late = max(max_late, late_by);
            };
            i = i + 1;
        };
        max_late < 86400 // Less than 1 day late
    }

    public fun get_is_critical(task: &Task): bool {
        task.is_critical
    }
    public fun get_end_time(task: &Task): u64 {
        task.end_time
    }
    public fun get_is_completed(task: &Task): bool {
        task.is_completed
    }

    public fun get_depends_on(task: &Task): &vector<ID> {
        &task.depends_on
    }
