using System.Globalization;

namespace SmartAgri.Api.Services;

public record AnalyticsPeriod(string Range, DateTime Start, DateTime End, DateTime LocalStart, DateTime LocalToday, bool Daily);
public record AnalyticsOrder(string Id, DateTime CreatedAt, string Customer, string Item, decimal Amount,
    string Status, string PaymentStatus, decimal Outstanding);
public record AnalyticsCollection(DateTime Date, decimal Amount, string Category);

public static class SalesAnalytics
{
    private static readonly TimeSpan Offset = TimeSpan.FromMinutes(330);

    public static AnalyticsPeriod Period(string range, DateTime utcNow)
    {
        var today = utcNow.Add(Offset).Date;
        var month = new DateTime(today.Year, today.Month, 1);
        var start = range switch
        {
            "This Week" => today.AddDays(-(((int)today.DayOfWeek + 6) % 7)),
            "This Month" => month,
            "Last 6 Months" => month.AddMonths(-5),
            "This Year" => new DateTime(today.Year, 1, 1),
            _ => throw new ArgumentException("Invalid range")
        };
        return new(range, DateTime.SpecifyKind(start - Offset, DateTimeKind.Utc), utcNow,
            start, today, range is "This Week" or "This Month");
    }

    public static object Build(AnalyticsPeriod period, IEnumerable<AnalyticsOrder> orders,
        IEnumerable<AnalyticsCollection> collections)
    {
        var activity = orders.Where(o => o.CreatedAt >= period.Start && o.CreatedAt < period.End)
            .OrderByDescending(o => o.CreatedAt).ThenBy(o => o.Id).ToList();
        var paid = collections.Where(p => p.Date >= period.Start && p.Date < period.End).ToList();
        var total = paid.Sum(p => p.Amount);
        var buckets = new List<object>();
        for (var day = period.LocalStart; day <= period.LocalToday;
            day = period.Daily ? day.AddDays(1) : day.AddMonths(1))
        {
            var next = period.Daily ? day.AddDays(1) : day.AddMonths(1);
            buckets.Add(new {
                name = day.ToString(period.Daily ? "dd MMM" : "MMM yyyy", CultureInfo.InvariantCulture),
                revenue = paid.Where(p => p.Date + Offset >= day && p.Date + Offset < next).Sum(p => p.Amount)
            });
        }
        return new {
            range = period.Range,
            from = period.Start,
            to = period.End,
            timezone = "Asia/Colombo",
            summary = new {
                totalRevenue = total,
                netProfit = (decimal?)null,
                totalOrders = activity.Count,
                pendingPayments = activity.Sum(o => o.Outstanding),
                orderValue = activity.Sum(o => o.Amount)
            },
            monthlyData = buckets,
            categoryData = paid.GroupBy(p => Category(p.Category)).Select(g => new {
                name = g.Key, amount = g.Sum(p => p.Amount),
                value = total == 0 ? 0 : Math.Round(g.Sum(p => p.Amount) / total * 100, 1)
            }).OrderByDescending(c => c.amount).ToList(),
            recentTransactions = activity.Select(o => new {
                id = o.Id, date = o.CreatedAt, customer = o.Customer, item = o.Item,
                amount = o.Amount, status = o.Status, paymentStatus = o.PaymentStatus,
                outstanding = o.Outstanding
            }).ToList()
        };
    }

    private static string Category(string value) => value switch {
        "MACHINERY" => "Machinery", "INPUTS" => "Inputs", "TRANSPORT" => "Transport", _ => value
    };
}
