insert into edge (
	parent_id,
	child_id,
	position)
select
	parent.id as parent_id ,
	child.id as child_id,
	child.position as position
from
	tasks parent
join tasks child on
	child.parent_id = parent.id and child.deleted_at is null;
