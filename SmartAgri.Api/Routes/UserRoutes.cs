namespace SmartAgri.Api.Routes;

public static class UserRoutes
{
    public const string Base = "/api/users";

    // Literal routes (no {id}) — these MUST be distinct from anything with {id:int}
    public const string GetAll = Base;
    public const string Create = Base;
    public const string Stats = Base + "/stats";

    // Parameterized routes — {id:int} constraint prevents "stats" (or any
    // non-numeric segment) from accidentally matching these and causing
    // a 400 from failed model binding.
    public const string GetById = Base + "/{id:int}";
    public const string Update = Base + "/{id:int}";
    public const string Delete = Base + "/{id:int}";
    public const string Activate = Base + "/{id:int}/activate";
    public const string Deactivate = Base + "/{id:int}/deactivate";
    public const string Block = Base + "/{id:int}/block";
    public const string ChangeRole = Base + "/{id:int}/role";
}