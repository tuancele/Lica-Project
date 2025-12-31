<?php

namespace Modules\Product\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class Origin extends Model
{
    use HasFactory;
    protected $table = 'origins';
    protected $guarded = [];
}
