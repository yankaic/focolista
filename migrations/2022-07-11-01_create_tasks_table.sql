create table tasks (
	id int primary key,
	description text,
	completed_at text,
	created_at text,
	updated_at text,
	deleted_at text,
	parent_id int,
	position int
);
