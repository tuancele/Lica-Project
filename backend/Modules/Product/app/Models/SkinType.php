<?php

namespace Modules\Product\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class SkinType extends Model
{
    use HasFactory;
    protected $table = 'skin_types';
    protected $guarded = [];
}
