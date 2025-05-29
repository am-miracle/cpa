module cpa::utils;
    use sui::vec_map::{Self, VecMap};
    use cpa::project_manager::Task;


    /// Find all critical path tasks in a project
    public fun get_critical_tasks(tasks: &VecMap<ID, Task>): vector<ID> {
        let mut critical_tasks = vector::empty<ID>();
        let keys = vec_map::keys(tasks);
        let len = vector::length(&keys);
        let mut i: u64 = 0;
        while (i < len) {
            let task_id = *vector::borrow(&keys, i);
            let task = vec_map::get(tasks, &task_id);
            let is_critical = cpa::project_manager::get_is_critical(task);
            if (is_critical) {
                vector::push_back(&mut critical_tasks, task_id);
            };
            i = i + 1;
        };
        critical_tasks
    }


    /// Calculate total project duration (longest path)
    public fun get_project_duration(tasks: &VecMap<ID, Task>): u64 {
        let keys = vec_map::keys(tasks);
        let len = vector::length(&keys);
        let mut max_end_time = 0u64;
        let mut i: u64 = 0;
        while (i < len) {
            let task_id = *vector::borrow(&keys, i);
            let task = vec_map::get(tasks, &task_id);
            let end_time = cpa::project_manager::get_end_time(task);
            if (end_time > max_end_time) {
                max_end_time = end_time;
            };
            i = i + 1;
        };
        max_end_time
    }


    /// Check if all dependencies are completed for a task
    public fun dependencies_completed(
        task: &Task,
        tasks: &VecMap<ID, Task>
    ): bool {
        let mut i = 0;
        let depends_on = cpa::project_manager::get_depends_on(task);
        while (i < vector::length(depends_on)) {
            let dep_id = *vector::borrow(depends_on, i);
            if (!vec_map::contains(tasks, &dep_id)) return false;
            let dep_task = vec_map::get(tasks, &dep_id);
            let is_completed = cpa::project_manager::get_is_completed(dep_task);
            if (!is_completed) return false;
            i = i + 1;
        };

        true
    }
