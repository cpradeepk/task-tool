import { Model } from '../db/index.js';

export class User extends Model {
  static get tableName() { return 'users'; }
  static get idColumn() { return 'id'; }
}

