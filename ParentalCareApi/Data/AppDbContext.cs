using Microsoft.EntityFrameworkCore;
using ParentalCareApi.Models;

namespace ParentalCareApi.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
    {
    }

    public DbSet<User> Users { get; set; }
    public DbSet<CareRelationship> CareRelationships { get; set; }
    public DbSet<Reminder> Reminders { get; set; }
    public DbSet<SosEvent> SosEvents { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // User configuration
        modelBuilder.Entity<User>(entity =>
        {
            entity.HasIndex(e => e.Email).IsUnique();
            entity.HasIndex(e => e.UniqueCode).IsUnique();

            entity.Property(e => e.Role)
                .HasConversion<string>();
        });

        // CareRelationship configuration
        modelBuilder.Entity<CareRelationship>(entity =>
        {
            entity.HasOne(e => e.Caregiver)
                .WithMany(u => u.CaregiverRelationships)
                .HasForeignKey(e => e.CaregiverId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(e => e.Dependent)
                .WithMany(u => u.DependentRelationships)
                .HasForeignKey(e => e.DependentId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasIndex(e => new { e.CaregiverId, e.DependentId, e.Status });
        });

        // Reminder configuration
        modelBuilder.Entity<Reminder>(entity =>
        {
            entity.HasOne(e => e.Creator)
                .WithMany(u => u.CreatedReminders)
                .HasForeignKey(e => e.CreatorId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(e => e.Dependent)
                .WithMany(u => u.AssignedReminders)
                .HasForeignKey(e => e.DependentId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasIndex(e => e.DependentId);
            entity.HasIndex(e => e.CreatorId);
        });

        // SosEvent configuration
        modelBuilder.Entity<SosEvent>(entity =>
        {
            entity.HasOne(e => e.Dependent)
                .WithMany(u => u.SosEvents)
                .HasForeignKey(e => e.DependentId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(e => e.Resolver)
                .WithMany()
                .HasForeignKey(e => e.ResolvedBy)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasIndex(e => e.DependentId);
            entity.HasIndex(e => new { e.DependentId, e.Status });
        });
    }
}
