create view summary as
select
	task.id,
	task.description,
	task.completed_at,
	parent_connection.parent_id as parent_id,
	parent_connection.position as position,
	count (child_task.completed_at) as completed_count,
	count(child_task.id) as subtasks_count
from
	tasks task 	
	left join edge parent_connection
	on parent_connection.child_id = task.id
	and parent_connection.deleted_at is null	
	left join edge child_connection
	on child_connection.parent_id = task.id
	and child_connection.deleted_at is null
	left join tasks child_task
	on child_connection.child_id = child_task.id
group by
	task.id
order by
	parent_connection.position;
