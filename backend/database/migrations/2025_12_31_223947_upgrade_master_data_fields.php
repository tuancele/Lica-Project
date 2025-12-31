<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        $tables = ['brands', 'origins', 'units', 'skin_types'];
        foreach ($tables as $table) {
            Schema::table($table, function (Blueprint $table) {
                if (!Schema::hasColumn($table->getTable(), 'slug')) $table->string('slug')->nullable()->unique();
                if (!Schema::hasColumn($table->getTable(), 'description')) $table->text('description')->nullable();
                if (!Schema::hasColumn($table->getTable(), 'image')) $table->string('image')->nullable();
            });
        }
    }
    public function down(): void {}
};
