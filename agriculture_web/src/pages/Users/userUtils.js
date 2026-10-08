export const ROLE_FILTERS = ['ALL', 'ADMIN', 'FARMER', 'CUSTOMER'];
export const ASSIGNABLE_ROLES = ['ADMIN', 'FARMER', 'CUSTOMER'];
export const isAssignableRole = (role) => ASSIGNABLE_ROLES.includes(role);
