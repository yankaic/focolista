create table stack_new (
	id int primary key not null,
    task_id int not null,
    foreign key(task_id) references tasks(id)
);

insert into stack_new select (id, task_id) from stack;

drop table stack;

alter table stack_new rename to stack;
