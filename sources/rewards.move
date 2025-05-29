module cpa::rewards;
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::vec_map::{Self};
    use cpa::project_manager::{Project};


    // ====== Structs ======
    public struct RewardPool<phantom T> has key {
        id: UID,
        balance: Balance<T>
    }

    public struct RewardReceipt has key {
        id: UID,
        amount: u64
    }

    // ====== Constants ======
    const E_NOT_ENOUGH_REWARDS: u64 = 100;
    const E_NOT_PROJECT_OWNER: u64 = 101;
    const E_TASK_NOT_FOUND: u64 = 102;
    const E_DEPENDENCY_NOT_MET: u64 = 103;


    // ====== Public Functions ======

    /// Initialize a new reward pool for a project
    public fun create_reward_pool<T>(
        project_owner: &mut TxContext,
        project: &Project,
        initial_balance: Balance<T>,
        ctx: &mut TxContext
    ): RewardPool<T> {
        assert!(cpa::project_manager::is_owner(project, tx_context::sender(project_owner)), E_NOT_PROJECT_OWNER);

        RewardPool {
            id: object::new(ctx),
            balance: initial_balance
        }
    }

    /// Reward a user for completing a task
    public fun reward_task_completion<T>(
        reward_pool: &mut RewardPool<T>,
        project: &Project,
        task_id: ID,
        recipient: address,
        amount: u64,
        ctx: &mut TxContext
    ): u64 {
        let tasks = cpa::project_manager::get_tasks(project);

        assert!(balance::value(&reward_pool.balance) >= amount, E_NOT_ENOUGH_REWARDS);

        // Verify task exists and is completed
        assert!(vec_map::contains(tasks, &task_id), E_TASK_NOT_FOUND);
        assert!(cpa::project_manager::is_task_completed(project, task_id), E_DEPENDENCY_NOT_MET);


        // Deduct from pool and create reward coin
        let reward_coin = coin::take(&mut reward_pool.balance, amount, ctx);
        let coin_value = coin::value(&reward_coin);
        assert!(coin::value(&reward_coin) == amount, E_NOT_ENOUGH_REWARDS);
        transfer::public_transfer(reward_coin, recipient);

        // Emit receipt (optional)
        let receipt = RewardReceipt {
            id: object::new(ctx),
            amount
        };
        transfer::transfer(receipt, recipient);

        coin_value
    }

    /// Withdraw unused rewards
    public fun withdraw_rewards<T>(
        reward_pool: &mut RewardPool<T>,
        owner: &mut TxContext
    ): Coin<T> {
        let amount = balance::value(&reward_pool.balance);
        coin::take(&mut reward_pool.balance, amount, owner)
    }
