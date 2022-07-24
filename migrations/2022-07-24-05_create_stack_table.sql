create table stack (
	id int primary key not null,
    task_id int not null,
    parent_id int,
    foreign key(task_id) references tasks(id),
	foreign key(parent_id) references tasks(id)
);
