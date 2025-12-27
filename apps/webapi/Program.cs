var builder = WebApplication.CreateBuilder(args);

// Add services to the container
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Configure CORS to allow Next.js frontend
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFrontend", policy =>
    {
        policy.WithOrigins(
            "http://localhost:3000",
            "http://webapp.local",
            "https://webapp.local"
        )
        .AllowAnyMethod()
        .AllowAnyHeader()
        .AllowCredentials();
    });
});

var app = builder.Build();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors("AllowFrontend");

// Health check endpoint
app.MapGet("/api/health", () =>
{
    var response = new
    {
        message = "API is running successfully!",
        timestamp = DateTime.UtcNow.ToString("o"),
        environment = app.Environment.EnvironmentName,
        version = "1.0.0"
    };

    return Results.Ok(response);
})
.WithName("HealthCheck")
.WithOpenApi();

// Additional sample endpoint
app.MapGet("/api/data", () =>
{
    var data = new
    {
        items = new[]
        {
            new { id = 1, name = "Sample Item 1", description = "This is a sample item" },
            new { id = 2, name = "Sample Item 2", description = "Another sample item" },
            new { id = 3, name = "Sample Item 3", description = "Yet another sample item" }
        },
        count = 3,
        timestamp = DateTime.UtcNow.ToString("o")
    };

    return Results.Ok(data);
})
.WithName("GetData")
.WithOpenApi();

// Root endpoint
app.MapGet("/", () => new
{
    service = "Sample Web API",
    framework = "ASP.NET Core 8.0",
    language = "C#",
    status = "Running",
    endpoints = new[]
    {
        "/api/health - Health check endpoint",
        "/api/data - Sample data endpoint",
        "/swagger - API documentation"
    }
})
.WithName("Root")
.WithOpenApi();

app.Run();
