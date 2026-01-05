<?php

namespace Modules\PriceEngine\Models;

use Illuminate\Database\Eloquent\Model;
use Modules\Product\Models\Product;

class ProgramItem extends Model
{
    protected $table = 'price_engine_items';
    protected $guarded = [];

    public function product()
    {
        return $this->belongsTo(Product::class);
    }

    public function program()
    {
        return $this->belongsTo(Program::class, 'program_id');
    }
}
