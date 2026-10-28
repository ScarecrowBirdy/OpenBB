/**
 *	
 */
module openbb.world.staticentity;

import dsfml.system.vector;
import openbb.world.entity;


///
class StaticEntity : Entity
{
private:
public:
	/// constructor
	this(Vector2f pos, Vector2i size)
	{
		super(pos, size);
	}
}