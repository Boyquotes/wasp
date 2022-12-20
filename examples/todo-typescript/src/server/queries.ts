import HttpError from '@wasp/core/HttpError.js';
import { Context, Task } from './serverTypes'

export const getTasks = async (args: null, context: Context): Promise<Task[]> => {
  if (!context.user) {
    throw new HttpError(401);
  }
  return context.entities.Task.findMany({ where: { user: { id: context.user.id } } });
};
