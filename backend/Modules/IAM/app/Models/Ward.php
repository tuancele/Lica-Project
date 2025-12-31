<?php
namespace Modules\IAM\Models;
use Illuminate\Database\Eloquent\Model;

class Ward extends Model
{
    protected $primaryKey = 'code';
    public $incrementing = false;
    protected $keyType = 'string';
    protected $guarded = [];

    public function district() {
        return $this->belongsTo(District::class, 'district_code', 'code');
    }
}
