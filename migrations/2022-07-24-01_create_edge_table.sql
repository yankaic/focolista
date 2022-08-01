create table edge (
	parent_id int not null,
	child_id int not null,
	position int not null,
	updated_at text,
	deleted_at text,
	foreign key(parent_id) references tasks(id),
	foreign key(child_id) references tasks(id)
);
